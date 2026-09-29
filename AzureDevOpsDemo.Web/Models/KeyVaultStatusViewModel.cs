namespace AzureDevOpsDemo.Web.Models;

public sealed class KeyVaultStatusViewModel
{
    public bool KeyVaultConnected { get; init; }
    public string? KeyVaultValue { get; init; }
}
