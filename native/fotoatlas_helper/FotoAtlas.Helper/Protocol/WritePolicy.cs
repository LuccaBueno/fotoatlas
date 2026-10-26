namespace FotoAtlas.Helper.Protocol;

/// <summary>
/// Regras de escrita do helper (docs/protocolo-helper.md §6). Toda gravação feita pelo
/// helper (Fases 3 e 4) passa por aqui antes de abrir o arquivo com <c>FileMode.CreateNew</c>.
/// </summary>
internal static class WritePolicy
{
    public const string TempDirName = ".fotoatlas-tmp";

    /// <summary>Destino de <c>devices.pullToFile</c>: absoluto, dentro de <c>.fotoatlas-tmp</c>, terminando em <c>.part</c>.</summary>
    public static bool IsAllowedPartPath(string path)
    {
        if (string.IsNullOrWhiteSpace(path) || !Path.IsPathFullyQualified(path)) return false;
        if (HasTraversal(path)) return false;
        var full = Path.GetFullPath(path);
        if (!full.EndsWith(".part", StringComparison.OrdinalIgnoreCase)) return false;
        var parent = Path.GetDirectoryName(full);
        return parent is not null && string.Equals(Path.GetFileName(parent), TempDirName, StringComparison.OrdinalIgnoreCase);
    }

    /// <summary>Destino de <c>thumbnails.get</c>: dentro do <c>--cache-dir</c>.</summary>
    public static bool IsWithinCacheDir(string path, string? cacheDir)
    {
        if (string.IsNullOrWhiteSpace(cacheDir) || string.IsNullOrWhiteSpace(path)) return false;
        if (!Path.IsPathFullyQualified(path) || HasTraversal(path)) return false;
        var root = Path.TrimEndingDirectorySeparator(Path.GetFullPath(cacheDir)) + Path.DirectorySeparatorChar;
        return Path.GetFullPath(path).StartsWith(root, StringComparison.OrdinalIgnoreCase);
    }

    private static bool HasTraversal(string path) =>
        path.Split('\\', '/').Any(segment => segment == "..");
}
