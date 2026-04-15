# Smart Node code patterns

Compile-ready C# examples for FloLess Smart Nodes. All samples follow root `CLAUDE.md`:
`is false` over `!`, no leading underscore on field names, `ConfigureAwait(false)` on every
`await`, one empty line between properties, latest C# syntax.

Before running `floless compile --code <file> --json`, read the SKILL.md body for the
`success: true` vs `data.compiled` gotcha (Pitfall 5). `data.compiled` is the real result.

---

## Entry point contract

Smart Nodes implement one of two interfaces from `FloLess.Core.Scripting.Interfaces`.

**Action** — performs an operation and returns output values:

```csharp
using System.Collections.Generic;
using System.Threading.Tasks;
using FloLess.Core.Scripting.Interfaces;
using FloLess.Core.Scripting;

namespace FloLessNodes;

public class MyAction : IScriptAction
{
    public async Task<Dictionary<string, object>> ExecuteAsync(
        Dictionary<string, object> inputs,
        ScriptContext context)
    {
        await Task.CompletedTask.ConfigureAwait(false);
        // inputs keys = inputSchema port names; return keys = outputSchema port names
        return new Dictionary<string, object> { ["result"] = "done" };
    }
}
```

**Trigger** — watches for events and yields trigger payloads (runtime keeps this running):

```csharp
using System.Collections.Generic;
using System.Runtime.CompilerServices;
using System.Threading;
using FloLess.Core.Scripting.Interfaces;
using FloLess.Core.Scripting;

namespace FloLessNodes;

public class MyTrigger : IScriptTrigger
{
    public async IAsyncEnumerable<Dictionary<string, object>> WatchAsync(
        ScriptContext context,
        [EnumeratorCancellation] CancellationToken cancellationToken)
    {
        while (cancellationToken.IsCancellationRequested is false)
        {
            await Task.Delay(5000, cancellationToken).ConfigureAwait(false);
            yield return new Dictionary<string, object>
            {
                ["timestamp"] = DateTimeOffset.UtcNow.ToString("o")
            };
        }
    }
}
```

`ScriptContext` provides: `CancellationToken`, `GetVariable<T>(name)`, `SetVariable(name, value)`,
`LogInfo(msg)`, `LogWarning(msg)`, `LogError(msg, ex?)`, `LogDebug(msg)`.

---

## Pattern 1: Echo node

Simplest valid `IScriptAction` — returns `value` input unchanged:

```csharp
using System.Collections.Generic;
using System.Threading.Tasks;
using FloLess.Core.Scripting.Interfaces;
using FloLess.Core.Scripting;

namespace FloLessNodes;

public class EchoNode : IScriptAction
{
    public async Task<Dictionary<string, object>> ExecuteAsync(
        Dictionary<string, object> inputs,
        ScriptContext context)
    {
        await Task.CompletedTask.ConfigureAwait(false);
        inputs.TryGetValue("value", out var value);
        return new Dictionary<string, object> { ["result"] = value ?? string.Empty };
    }
}
```

---

## Pattern 2: JSON transform

Parses a JSON string, extracts a named property. `System.Text.Json` is always available:

```csharp
using System.Collections.Generic;
using System.Text.Json;
using System.Threading.Tasks;
using FloLess.Core.Scripting.Interfaces;
using FloLess.Core.Scripting;

namespace FloLessNodes;

public class JsonExtractNode : IScriptAction
{
    public async Task<Dictionary<string, object>> ExecuteAsync(
        Dictionary<string, object> inputs,
        ScriptContext context)
    {
        await Task.CompletedTask.ConfigureAwait(false);

        if (inputs.TryGetValue("json", out var raw) is false || raw is null)
            return new Dictionary<string, object> { ["value"] = string.Empty, ["found"] = false };

        if (inputs.TryGetValue("property", out var prop) is false || prop is null)
            return new Dictionary<string, object> { ["value"] = string.Empty, ["found"] = false };

        var doc = JsonDocument.Parse(raw.ToString()!);

        if (doc.RootElement.TryGetProperty(prop.ToString()!, out var element))
            return new Dictionary<string, object> { ["value"] = element.ToString(), ["found"] = true };

        return new Dictionary<string, object> { ["value"] = string.Empty, ["found"] = false };
    }
}
```

---

## Pattern 3: Async external API call

Makes an HTTP GET request. Requires `allowHttpNetworking` enabled in FloLess Settings →
Smart Node → Assemblies. Without it, compile succeeds but runtime throws `TypeLoadException`.

```csharp
using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Threading.Tasks;
using FloLess.Core.Scripting.Interfaces;
using FloLess.Core.Scripting;

namespace FloLessNodes;

public class HttpGetNode : IScriptAction
{
    private static readonly HttpClient httpClient = new HttpClient
    {
        Timeout = TimeSpan.FromSeconds(30)
    };

    public async Task<Dictionary<string, object>> ExecuteAsync(
        Dictionary<string, object> inputs,
        ScriptContext context)
    {
        if (inputs.TryGetValue("url", out var urlObj) is false || urlObj is null)
        {
            context.LogError("Input 'url' is required");
            return new Dictionary<string, object> { ["body"] = string.Empty, ["success"] = false };
        }

        var response = await httpClient.GetAsync(urlObj.ToString()!, context.CancellationToken)
            .ConfigureAwait(false);

        var body = await response.Content.ReadAsStringAsync().ConfigureAwait(false);

        return new Dictionary<string, object>
        {
            ["body"] = body,
            ["statusCode"] = (int)response.StatusCode,
            ["success"] = response.IsSuccessStatusCode
        };
    }
}
```

---

## Pattern 4: Collection aggregation

Aggregates a JSON number array. Uses LINQ (always available) and `is false` pattern:

```csharp
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;
using FloLess.Core.Scripting.Interfaces;
using FloLess.Core.Scripting;

namespace FloLessNodes;

public class AggregateNode : IScriptAction
{
    public async Task<Dictionary<string, object>> ExecuteAsync(
        Dictionary<string, object> inputs,
        ScriptContext context)
    {
        await Task.CompletedTask.ConfigureAwait(false);

        if (inputs.TryGetValue("items", out var itemsObj) is false || itemsObj is null)
            return new Dictionary<string, object> { ["count"] = 0, ["sum"] = 0.0 };

        var doc = JsonDocument.Parse(itemsObj.ToString()!);

        var numbers = doc.RootElement
            .EnumerateArray()
            .Where(e => e.ValueKind == JsonValueKind.Number)
            .Select(e => e.GetDouble())
            .ToList();

        if (numbers.Count is 0)
            return new Dictionary<string, object> { ["count"] = 0, ["sum"] = 0.0 };

        var sum = numbers.Sum();
        context.LogInfo($"Aggregated {numbers.Count} numbers, sum={sum}");

        return new Dictionary<string, object>
        {
            ["count"] = numbers.Count,
            ["sum"] = sum,
            ["average"] = sum / numbers.Count
        };
    }
}
```

---

## Pattern 5: Tekla-targeted node (net48)

Stub for a Smart Node that uses Tekla OpenAPI. Must compile with
`--target-framework net48 --software-version tekla-2025`. Never compile with `net8.0` —
Tekla types are .NET Framework 4.8 only and produce `CS0246` on net8.0.

```csharp
using System.Collections.Generic;
using System.Threading.Tasks;
using Tekla.Structures.Model;
using FloLess.Core.Scripting.Interfaces;
using FloLess.Core.Scripting;

namespace FloLessNodes;

public class TeklaModelInfoNode : IScriptAction
{
    public async Task<Dictionary<string, object>> ExecuteAsync(
        Dictionary<string, object> inputs,
        ScriptContext context)
    {
        await Task.CompletedTask.ConfigureAwait(false);

        var model = new Model();

        if (model.GetConnectionStatus() is false)
        {
            context.LogError("Tekla Structures is not running or not connected");
            return new Dictionary<string, object> { ["modelName"] = string.Empty, ["connected"] = false };
        }

        var info = model.GetInfo();
        return new Dictionary<string, object>
        {
            ["modelName"] = info.ModelName,
            ["modelPath"] = info.ModelPath,
            ["connected"] = true
        };
    }
}
```

Compile command:

```bash
floless compile --code tekla-node.cs --target-framework net48 --software-version tekla-2025 --json
```

To update a specific workflow node in-place:

```bash
floless compile --code tekla-node.cs --target-framework net48 --software-version tekla-2025 \
  --workflow current --node {nodeId} --json
```

`nodeUpdated: true` in the response confirms the live workflow was updated.

---

## Common compile errors and fixes

| Code | Message pattern | Fix |
|---|---|---|
| `CS0103` | `'foo' does not exist in the current context` | Add missing `using` directive or fix variable name/scope |
| `CS0246` | `'HttpClient' could not be found` | Enable the required assembly in Settings → Smart Node → Assemblies |
| `CS0117` | `'JsonValueKind' does not contain 'Obj'` | Check exact enum/member name — e.g., `JsonValueKind.Object` not `.Obj` |
| `CS1061` | `'string' does not contain 'IsNullOrEmpty'` | Use `string.IsNullOrEmpty(x)` (static) or add `using FloLess.Core.Extensions` for dict extension |
| `CS0234` | `'Linq' does not exist in namespace 'System'` | Correct the namespace — `using System.Linq;` not `using System.Linq.Enumerable;` |
| `CS0161` | `not all code paths return a value` | Add a fallback `return` after all conditional branches |
| `CS0029` | `cannot implicitly convert` | Add explicit cast or correct the type |

For each entry in `data.diagnostics[]`, use `line` and `column` to locate the error in
your source file, match the `id` to the table above, apply the fix, and recompile.

---

## The compile-fix loop in practice

**The critical check:** after every `floless compile --code file.cs --json`, inspect
`data.compiled` — not `success`. `success: true` only means the API call reached the
desktop. `data.compiled: false` means your C# has errors. Repeat until `data.compiled: true`.

Iteration 1 — response with error:
```json
{
  "success": true,
  "data": {
    "compiled": false,
    "diagnostics": [
      { "severity": "Error", "id": "CS0103", "message": "The name 'httpClient' does not exist", "line": 22, "column": 22 }
    ]
  }
}
```
Action: open file at line 22, fix the missing field declaration, recompile.

Iteration 2 — response when fixed:
```json
{
  "success": true,
  "data": { "compiled": true, "diagnostics": [], "nodeUpdated": false, "targetFramework": "net8.0" }
}
```
`data.compiled: true` — done.

---

## References

- Root `CLAUDE.md` — C# coding conventions for all FloLess code
- `src/FloLess/Core/Scripting/Interfaces/IScriptAction.cs` — action entry point
- `src/FloLess/Core/Scripting/Interfaces/IScriptTrigger.cs` — trigger entry point
- `src/FloLess/Core/Scripting/ScriptContext.cs` — runtime context API
- `src/FloLess/Core/Services/SmartNode/SmartNodeReferenceBuilder.cs` — allowed assemblies
- `src/FloLess.CLI/Commands/CompileCommand.cs` — exact compile command option names
- `floless-cli` skill — envelope parsing, port file, exit codes
- SKILL.md — compile-fix loop procedure, full diagnostic sequence
