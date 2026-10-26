using FotoAtlas.Helper.Protocol;
using FotoAtlas.Helper.Volumes;

namespace FotoAtlas.Helper.Tests;

public class VolumeTests
{
    [Fact]
    public void ListaIncluiOVolumeDoSistema()
    {
        var volumes = new VolumeEnumerator().List();
        var systemRoot = Path.GetPathRoot(Environment.SystemDirectory)!;
        var boot = Assert.Single(volumes, v => v.IsBoot);
        Assert.Contains(boot.MountPoints, m => string.Equals(m, systemRoot, StringComparison.OrdinalIgnoreCase));
        Assert.StartsWith("\\\\?\\Volume{", boot.GuidPath);
        Assert.NotNull(boot.Serial);
        Assert.NotNull(boot.FileSystem);
        Assert.True(boot.TotalBytes > 0);
    }

    [Fact]
    public void ParseMultiSzSeparaCaminhos()
    {
        var parsed = VolumeEnumerator.ParseMultiSz("C:\\\0D:\\Montado\\\0\0lixo".AsSpan());
        Assert.Equal(["C:\\", "D:\\Montado\\"], parsed);
    }

    [Theory]
    [InlineData("WD-WX12A3456789", 1, "reliable")]
    [InlineData("000000000000", 1, "weak")]
    [InlineData("    ", 1, "weak")]
    [InlineData("FFFFFFFF", 1, "weak")]
    [InlineData("ABC", 1, "weak")]
    [InlineData("WD-WX12A3456789", 2, "weak")]
    [InlineData("0000_0000_0000_0000_0000_0100_0000_0000.", 1, "weak")]
    [InlineData("S4EWNX0R123456", 1, "reliable")]
    public void ClassificaIdentidadeDoDisco(string serial, int sameSerialCount, string expected)
    {
        Assert.Equal(expected, DiskIdentity.Classify(serial, "Modelo X", 1000, sameSerialCount));
    }

    [Fact]
    public void SemSerialNemModeloEhDesconhecido()
    {
        Assert.Equal("unknown", DiskIdentity.Classify(null, null, null, 0));
    }

    [Fact]
    public void BusTypeConhecidos()
    {
        Assert.Equal("usb", VolumeEnumerator.BusTypeName(7));
        Assert.Equal("nvme", VolumeEnumerator.BusTypeName(17));
        Assert.Equal("unknown", VolumeEnumerator.BusTypeName(999));
    }
}

public class WritePolicyTests
{
    [Theory]
    [InlineData(@"E:\Fotos\.fotoatlas-tmp\0b1c.part", true)]
    [InlineData(@"E:\.fotoatlas-tmp\abc.PART", true)]
    [InlineData(@"E:\Fotos\abc.part", false)]
    [InlineData(@"E:\Fotos\.fotoatlas-tmp\abc.jpg", false)]
    [InlineData(@"E:\Fotos\.fotoatlas-tmp\..\abc.part", false)]
    [InlineData(@".fotoatlas-tmp\abc.part", false)]
    [InlineData(@"E:\Fotos\.fotoatlas-tmp\sub\abc.part", false)]
    [InlineData("", false)]
    public void RegrasDoPart(string path, bool allowed)
    {
        Assert.Equal(allowed, WritePolicy.IsAllowedPartPath(path));
    }

    [Theory]
    [InlineData(@"C:\cache\thumbs\a.jpg", true)]
    [InlineData(@"C:\cache\a.jpg", true)]
    [InlineData(@"C:\cacheX\a.jpg", false)]
    [InlineData(@"C:\cache\..\a.jpg", false)]
    [InlineData(@"C:\outro\a.jpg", false)]
    public void RegrasDoCache(string path, bool allowed)
    {
        Assert.Equal(allowed, WritePolicy.IsWithinCacheDir(path, @"C:\cache"));
    }

    [Fact]
    public void SemCacheDirNadaEhPermitido()
    {
        Assert.False(WritePolicy.IsWithinCacheDir(@"C:\cache\a.jpg", null));
    }
}
