using System.Diagnostics;
using System.Text;
using FotoAtlas.Helper.Devices;
using FotoAtlas.Helper.Devices.Fake;
using FotoAtlas.Helper.Devices.Wpd;
using FotoAtlas.Helper.Protocol;
using FotoAtlas.Helper.Volumes;

namespace FotoAtlas.Helper;

internal static class Program
{
    private static async Task<int> Main(string[] args)
    {
        var protocol = ArgValue(args, "--protocol");
        if (protocol is not null && protocol != ProtocolHost.ProtocolVersion.ToString())
        {
            Console.Error.WriteLine($"Protocolo {protocol} não suportado (este helper fala v{ProtocolHost.ProtocolVersion}).");
            return 2;
        }

        var utf8 = new UTF8Encoding(encoderShouldEmitUTF8Identifier: false);
        using var stdin = new StreamReader(Console.OpenStandardInput(), utf8);
        using var stdout = new StreamWriter(Console.OpenStandardOutput(), utf8) { AutoFlush = false };
        // --fake-devices: celulares simulados (testes e demonstração), no lugar do WPD.
        var fakeDevices = ArgValue(args, "--fake-devices");
        IDeviceBackend devices = fakeDevices is not null ? new FakeDeviceBackend(Path.GetFullPath(fakeDevices)) : new WpdBackend();
        if (fakeDevices is not null) Console.Error.WriteLine($"[helper] celulares simulados de {fakeDevices}");
        var host = new ProtocolHost(stdin, stdout, new VolumeEnumerator(), Console.Error, devices);

        var waiters = new List<Task> { host.RunAsync(), host.ShutdownRequested };
        if (int.TryParse(ArgValue(args, "--parent-pid"), out var parentPid))
        {
            try
            {
                waiters.Add(Process.GetProcessById(parentPid).WaitForExitAsync());
            }
            catch (ArgumentException)
            {
                Console.Error.WriteLine($"Processo pai {parentPid} não existe; encerrando.");
                return 3;
            }
        }

        // Encerra no EOF do stdin, em system.shutdown ou quando o processo pai morre.
        await Task.WhenAny(waiters);
        return 0;
    }

    private static string? ArgValue(string[] args, string name)
    {
        var i = Array.IndexOf(args, name);
        return i >= 0 && i + 1 < args.Length ? args[i + 1] : null;
    }
}
