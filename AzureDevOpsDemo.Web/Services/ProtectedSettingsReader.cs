namespace AzureDevOpsDemo.Web.Services;

public sealed class ProtectedSettingsReader
{
    private const string DemoValueKey = "KeyVaultDemo:Value";
    private readonly IConfiguration _configuration;

    public ProtectedSettingsReader(IConfiguration configuration)
    {
        _configuration = configuration;
    }

    public bool TryGetDemoValue(out string? value)
    {
        value = _configuration[DemoValueKey];

        bool isResolved = !string.IsNullOrWhiteSpace(value) &&
                          !value.StartsWith("@Microsoft.KeyVault(", StringComparison.OrdinalIgnoreCase);

        if (!isResolved)
        {
            value = null;
        }

        return isResolved;
    }

    public string GetRequiredDemoValue()
    {
        if (!TryGetDemoValue(out string? value))
        {
            throw new InvalidOperationException(
                $"The configuration value '{DemoValueKey}' is missing or its Key Vault reference is unresolved.");
        }

        return value!;
    }
}
