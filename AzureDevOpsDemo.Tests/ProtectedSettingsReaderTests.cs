using AzureDevOpsDemo.Web.Services;
using Microsoft.Extensions.Configuration;
using Xunit;

namespace AzureDevOpsDemo.Tests;

public sealed class ProtectedSettingsReaderTests
{
    [Fact]
    public void TryGetDemoValue_WhenValueExists_ReturnsTrueAndValue()
    {
        var configuration = new ConfigurationManager
        {
            ["KeyVaultDemo:Value"] = "test-value"
        };
        var reader = new ProtectedSettingsReader(configuration);

        bool result = reader.TryGetDemoValue(out string? value);

        Assert.True(result);
        Assert.Equal("test-value", value);
    }

    [Fact]
    public void TryGetDemoValue_WhenValueIsMissing_ReturnsFalseAndNull()
    {
        var reader = new ProtectedSettingsReader(new ConfigurationManager());

        bool result = reader.TryGetDemoValue(out string? value);

        Assert.False(result);
        Assert.Null(value);
    }

    [Fact]
    public void TryGetDemoValue_WhenReferenceIsUnresolved_ReturnsFalseAndNull()
    {
        var configuration = new ConfigurationManager
        {
            ["KeyVaultDemo:Value"] = "@Microsoft.KeyVault(VaultName=example;SecretName=example)"
        };
        var reader = new ProtectedSettingsReader(configuration);

        bool result = reader.TryGetDemoValue(out string? value);

        Assert.False(result);
        Assert.Null(value);
    }
}
