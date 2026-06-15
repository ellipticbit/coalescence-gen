# Coalescence

Coalescence is a cross-language code-generation tool for the Coalescence Web API ecosystem. It bridges the gap between database schemas and application code by automatically generating models, endpoints, client libraries, and database contexts for various frameworks, streamlining full-stack development without the boilerplate.

## Usage

Run the `coalesce` command-line tool with options to specify your source database or project file:

```console
coalesce [options]
```

### Command-Line Options

| Option | Description |
|--------|-------------|
| `-h`, `--help` | Display the help information and exit. |
| `-rd`, `--root-directory <dir>` | Specifies the root directory of the project. |
| `-pf`, `--project-file <file>` | Specifies the path to the project file (defaults to `.coalescence.sdl` in the root). |
| `--db-mssql` | Indicates the source database is Microsoft SQL Server. |
| `--db-mysql` | Indicates the source database is MySQL or MariaDB. |
| `--db-postgresql` | Indicates the source database is PostgreSQL. |
| `--db-server <host>` | The hostname or IP address of the database server. |
| `--db-name <name>` | The name of the database to read from (required for MySQL / PostgreSQL). |
| `--db-user <user>` | The username for database authentication. |
| `--db-password <pass>`| The password for database authentication. |

## Project Configuration (`.coalescence.sdl`)

Coalescence uses [SDLang](https://sdlang.org/) for its project configuration. By default, it looks for a `.coalescence.sdl` file in the project's root directory.

### Example

```sdl
project {
    exclude:database "Migrations" "SystemFiles"
    exclude:client "SecretModels"

    generators:csharp {
        server outputPath="out/server" namespace="MyProject.Server" shortTransports=true {
            serializers "SystemTextJson"
        }
        client outputPath="out/client" namespace="MyProject.Client" uiBindings=true changeTracking=true {
            serializers "SystemTextJson" "NewtonsoftJson"
        }
    }
}
```

### Configuration Options

| Option | Type | Description |
|--------|------|-------------|
| `exclude:database` | Node Values | A list of schema or model names to entirely exclude during database reads. |
| `exclude:client` | Node Values | A list of schema or model names to filter out of the client generation. |
| `outputPath` | Attribute | **Required.** The path (relative to the project root) where generated files will be placed. |
| `outputMode` | Attribute | Describes how files are grouped. Values: `FilePerObject` (default), `FilePerSchema`, `SingleFile`. |
| `namespace` | Attribute | The base namespace/package name applied to generated code. |
| `contextName` | Attribute | Replaces the name of the generated Database Context (defaults to the database name). |
| `uiBindings` | Attribute | Boolean. Generates classes that implement data-binding (e.g. `BindingObject`). |
| `serializeFields` | Attribute | Boolean. Configures serializers to target fields instead of properties. |
| `shortTransports` | Attribute | Boolean. Shortens transport/payload names for network serialization to save bandwidth. |
| `changeTracking` | Attribute | Boolean. Generates change-tracking features on objects (e.g. `TrackingObject`). |
| `enableEFExtensions`| Attribute | Boolean. Enables Coalescence Entity Framework Core Extensions (`IDatabaseMergeable`, etc.). |
| `enableEFLazyLoading`| Attribute | Boolean. Modifies generated properties to support EF Core proxy lazy-loading (`virtual`). |
| `enableEFContextMocking` | Attribute | Boolean. Replaces `sealed` modifiers and makes Context `DbSet` properties `virtual` for mocking. |
| `serializers` | Node Values | A list of serializers to support. E.g. `"SystemTextJson"`, `"NewtonsoftJson"`, `"DataContract"`. |

## Contributing

Contributions to Coalescence are welcome! Please submit patches and features via Pull Requests. 

**Important LLM Guideline:** If you use a Large Language Model (such as GitHub Copilot, ChatGPT, Claude, etc.) to generate or assist heavily with your contribution, **you must include the exact prompt(s) you used to generate the code in the `PROMPTS.txt` file at the root of the repository.**

## License

This project is licensed under the Boost Software License 1.0 (BSL-1.0). See the `LICENSE` file for details.
