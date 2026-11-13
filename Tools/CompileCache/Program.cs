using System.Diagnostics;
using System.Security.Cryptography;
using System.Text;

namespace Helix.CompileCache;

/// <summary>
/// A compiler launcher that keeps object files by what they are made of: the source as the preprocessor gives it and
/// the command line, with the folders of the Helix repositories and of the build written as names (so the copies of a
/// repository in the External folders of different repositories share their objects). A hit copies the stored object
/// and tells the build the includes the preprocessor found; a miss compiles and stores.
///   HelixCompileCache --cache folder --map file -- compiler arguments...
///   HelixCompileCache --cache folder --prune gigabytes
/// The map file has a line per folder: the folder, a tab, its name.
/// </summary>
static class Program
{
    const string Version = "1";

    static int Main(string[] args)
    {
        try
        {
            return Run(args);
        }
        catch (Exception e)
        {
            Console.Error.WriteLine($"HelixCompileCache: {e.Message}");
            return 1;
        }
    }

    static int Run(string[] args)
    {
        string cache = null, map = null;
        double prune = -1;
        int i = 0;
        for (; i < args.Length; i++)
        {
            if (args[i] == "--")
            {
                i++;
                break;
            }
            switch (args[i])
            {
            case "--cache": cache = args[++i]; break;
            case "--map": map = args[++i]; break;
            case "--prune": prune = double.Parse(args[++i], System.Globalization.CultureInfo.InvariantCulture); break;
            default: throw new ArgumentException($"unknown argument {args[i]}");
            }
        }
        if (cache == null)
            throw new ArgumentException("--cache is missing");
        if (prune >= 0)
        {
            Prune(cache, (long)(prune * 1024 * 1024 * 1024));
            return 0;
        }
        string[] command = args[i..];
        if (command.Length == 0)
            throw new ArgumentException("no compiler command");
        var call = Call.Parse(command);
        if (call == null)
        {
            Log("not a compile to an object: " + string.Join(" ", command));
            return Exec(command, passOutput: true).Code;
        }
        return Compile(call, command, cache, map == null ? new List<(string, string)>() : ReadMap(map));
    }

    // ---------------------------------------------------------------------------------------------- the command

    sealed class Call
    {
        public bool Msvc;
        public string Output;
        // Indices of the arguments that name the output, the input and the dependency file (not part of the key).
        public HashSet<int> Skip = new();
        public int OutputIndex = -1;

        // The compiler's place in the command (launchers such as `cmake -E env` may come first).
        public static int CompilerIndex(string[] c)
        {
            for (int k = 0; k < c.Length; k++)
            {
                string name = Path.GetFileNameWithoutExtension(c[k].Replace('\\', '/').Split('/')[^1]).ToLowerInvariant();
                if (name is "cl" or "clang" or "clang++" or "em++" or "emcc" or "g++" or "gcc" or "c++" or "cc" ||
                    name.StartsWith("clang-") || name.StartsWith("clang++-") || name.EndsWith("-clang") || name.EndsWith("-clang++"))
                    return k;
            }
            return 0;
        }

        public static Call Parse(string[] c)
        {
            var call = new Call();
            bool hasCompileOnly = false;
            for (int k = CompilerIndex(c) + 1; k < c.Length; k++)
            {
                string a = c[k];
                if (a == "/c" || a == "-c")
                {
                    hasCompileOnly = true;
                    if (k + 1 < c.Length)
                        call.Skip.Add(k + 1);
                }
                else if (a.StartsWith("/Fo", StringComparison.Ordinal) && a.Length > 3)
                {
                    call.Msvc = true;
                    call.Output = a[3..];
                    call.OutputIndex = k;
                    call.Skip.Add(k);
                }
                else if (a.StartsWith("/Fd", StringComparison.Ordinal))
                    call.Skip.Add(k);
                else if (a == "-o" && k + 1 < c.Length)
                {
                    call.Output = c[k + 1];
                    call.OutputIndex = k + 1;
                    call.Skip.Add(k + 1);
                }
                else if ((a == "-MF" || a == "-MT" || a == "-MQ") && k + 1 < c.Length)
                    call.Skip.Add(k + 1);
                else if (a.StartsWith("@", StringComparison.Ordinal) || a == "/P" || a == "-E" || a == "-S")
                    return null;
            }
            // Only compiles to an object file are kept.
            return hasCompileOnly && call.Output != null ? call : null;
        }
    }

    static int Compile(Call call, string[] command, string cache, List<(string From, string To)> map)
    {
        string temp = Path.Combine(Path.GetTempPath(), $"helix-cc-{Environment.ProcessId}-{Guid.NewGuid():N}.i");
        try
        {
            // The preprocessor's text and the includes it read.
            string[] pre = Preprocess(call, command, temp);
            var p = Exec(pre, passOutput: false);
            if (p.Code != 0 || !File.Exists(temp))
            {
                Log($"the preprocessor failed ({p.Code}): {string.Join(" ", pre)}\n{p.Error}");
                return Exec(command, passOutput: true).Code;
            }
            string key = Key(call, command, temp, map);
            string stored = Path.Combine(cache, "objects", key[..2], key + ".o");
            string output = Path.GetFullPath(call.Output);
            if (File.Exists(stored))
            {
                Directory.CreateDirectory(Path.GetDirectoryName(output)!);
                File.Copy(stored, output, true);
                File.SetLastWriteTimeUtc(stored, DateTime.UtcNow);
                // MSVC's /showIncludes went to stderr under /P: the build reads it from stdout.
                if (call.Msvc)
                    foreach (string line in p.Error.Split('\n'))
                        if (line.StartsWith("Note: including file:", StringComparison.Ordinal))
                            Console.Out.WriteLine(line.TrimEnd('\r'));
                Log("hit " + call.Output);
                return 0;
            }
            int code = Exec(command, passOutput: true).Code;
            Log($"miss {call.Output} ({code})");
            if (code == 0 && File.Exists(output))
            {
                Directory.CreateDirectory(Path.GetDirectoryName(stored)!);
                string part = stored + "." + Guid.NewGuid().ToString("N") + ".part";
                File.Copy(output, part, true);
                try
                {
                    File.Move(part, stored, false);
                }
                catch (IOException)
                {
                    File.Delete(part);
                }
            }
            return code;
        }
        finally
        {
            try
            {
                File.Delete(temp);
            }
            catch (IOException)
            {
            }
        }
    }

    // The command made a preprocessor run into the temp file (the dependency file of -MD is written by it too).
    static string[] Preprocess(Call call, string[] c, string temp)
    {
        var list = new List<string>();
        for (int k = 0; k < c.Length; k++)
        {
            if (call.Msvc && k == call.OutputIndex)
            {
                list.Add("/P");
                list.Add("/Fi" + temp);
                continue;
            }
            if (!call.Msvc && k == call.OutputIndex)
            {
                list.Add(temp);
                continue;
            }
            // -E instead of -c (an unused -c is a warning, an error under -Werror).
            if (!call.Msvc && c[k] == "-c")
            {
                list.Add("-E");
                continue;
            }
            list.Add(c[k]);
        }
        return list.ToArray();
    }

    static string Key(Call call, string[] c, string temp, List<(string From, string To)> map)
    {
        using var hash = IncrementalHash.CreateHash(HashAlgorithmName.SHA256);
        void Add(string s)
        {
            byte[] b = Encoding.UTF8.GetBytes(s);
            hash.AppendData(BitConverter.GetBytes(b.Length));
            hash.AppendData(b);
        }
        Add(Version);
        for (int k = 0; k < c.Length; k++)
            Add(call.Skip.Contains(k) ? "?" : Normalize(c[k], map));
        // The compiler itself: its file's size and time.
        string compiler = c[Call.CompilerIndex(c)];
        if (File.Exists(compiler))
        {
            var info = new FileInfo(compiler);
            Add($"{info.Length}:{info.LastWriteTimeUtc.Ticks}");
        }
        Add(Normalize(File.ReadAllText(temp), map));
        return Convert.ToHexString(hash.GetHashAndReset()).ToLowerInvariant();
    }

    // The folders of the map as their names, in each spelling the tools write them (separators, escaped backslashes).
    static string Normalize(string text, List<(string From, string To)> map)
    {
        foreach ((string from, string to) in map)
        {
            string forward = from.Replace('\\', '/');
            string back = from.Replace('/', '\\');
            text = text.Replace(back.Replace("\\", "\\\\"), to, StringComparison.OrdinalIgnoreCase);
            text = text.Replace(back, to, StringComparison.OrdinalIgnoreCase);
            text = text.Replace(forward, to, StringComparison.OrdinalIgnoreCase);
        }
        return text;
    }

    static List<(string, string)> ReadMap(string file)
    {
        var list = new List<(string, string)>();
        foreach (string line in File.ReadAllLines(file))
        {
            int tab = line.IndexOf('\t');
            if (tab > 0)
                list.Add((line[..tab], line[(tab + 1)..]));
        }
        // Longer folders first (the build folder and External folders are inside the repository).
        list.Sort((a, b) => b.Item1.Length.CompareTo(a.Item1.Length));
        return list;
    }

    // HELIX_BUILD_CACHE_LOG names a file: what each call did is appended to it.
    static void Log(string line)
    {
        string file = Environment.GetEnvironmentVariable("HELIX_BUILD_CACHE_LOG");
        if (string.IsNullOrEmpty(file))
            return;
        for (int attempt = 0; attempt < 5; attempt++)
            try
            {
                File.AppendAllText(file, line + "\n");
                return;
            }
            catch (IOException)
            {
                Thread.Sleep(10);
            }
    }

    // ---------------------------------------------------------------------------------------------- processes

    readonly record struct Result(int Code, string Error);

    static Result Exec(string[] command, bool passOutput)
    {
        var info = new ProcessStartInfo(command[0]) { UseShellExecute = false };
        foreach (string a in command.Skip(1))
            info.ArgumentList.Add(a);
        if (passOutput)
        {
            using var process = Process.Start(info)!;
            process.WaitForExit();
            return new Result(process.ExitCode, "");
        }
        info.RedirectStandardOutput = true;
        info.RedirectStandardError = true;
        using var p = Process.Start(info)!;
        var stdout = p.StandardOutput.ReadToEndAsync();
        string stderr = p.StandardError.ReadToEnd();
        stdout.Wait();
        p.WaitForExit();
        return new Result(p.ExitCode, stdout.Result + stderr);
    }

    // ---------------------------------------------------------------------------------------------- pruning

    // The objects used least lately go until the cache is at most the size.
    static void Prune(string cache, long max)
    {
        string dir = Path.Combine(cache, "objects");
        if (!Directory.Exists(dir))
            return;
        var files = new DirectoryInfo(dir).EnumerateFiles("*", SearchOption.AllDirectories).ToList();
        long total = files.Sum(f => f.Length);
        foreach (FileInfo f in files.OrderBy(f => f.LastWriteTimeUtc))
        {
            if (total <= max)
                break;
            try
            {
                long size = f.Length;
                f.Delete();
                total -= size;
            }
            catch (IOException)
            {
            }
        }
    }
}
