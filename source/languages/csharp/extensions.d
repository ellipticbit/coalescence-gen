module coalescence.languages.csharp.extensions;

import coalescence.schema;
import coalescence.stringbuilder;
import coalescence.utility;

import std.algorithm.iteration;
import std.algorithm.searching;
import std.array;
import std.conv;
import std.file;
import std.path;
import std.typecons;
import std.stdio;
import std.string;

import sdlite;

public enum CSharpSerializers {
	SystemTextJson,
	NewtonsoftJson,
	DataContract,
/*	Currently Unsupported - Planned
	MessagePack,
	Protobuf,
*/
}

public enum CSharpOutputMode {
	FilePerObject,
	FilePerSchema,
	SingleFile,
}

public enum CSharpCompatibility {
	NET60,
	NET80
}

public enum CSharpGeneratorMode {
	Server,
	Client,
	Database,
}

public final class CSharpProjectOptions {
	public CSharpGeneratorMode mode;
	public CSharpOutputMode outputMode;
	public string outputPath;
	public string contextName;
	public string namespace;
	public bool uiBindings;
	public bool enableEFExtensions;
	public CSharpCompatibility compatibility;
	public CSharpSerializers[] serializers;

	public this (SDLNode root, string databaseName, string projectRoot) {
		if (root.name.toUpper() == "Database".toUpper()) mode = CSharpGeneratorMode.Database;
		else if (root.name.toUpper() == "Server".toUpper()) mode = CSharpGeneratorMode.Server;
		else if (root.name.toUpper() == "Client".toUpper()) mode = CSharpGeneratorMode.Client;
		else throw new Exception("Invalid generator mode specified: " ~ root.name);
		this.outputMode = to!CSharpOutputMode(root.getAttributeValue!string("outputMode", "FilePerObject"));
		this.contextName = root.getAttributeValue!string("contextName", databaseName);
		this.namespace = root.getAttributeValue!string("namespace", databaseName);
		this.uiBindings = root.getAttributeValue!bool("uiBindings", false);
		this.enableEFExtensions = root.getAttributeValue!bool("enableEFExtensions", false);
		this.compatibility = to!CSharpCompatibility(root.getAttributeValue!string("compatibility", "NET80"));
		try {
			version(Posix) {
			this.outputPath = buildNormalizedPath(projectRoot, root.expectAttributeValue!string("outputPath").replace("\\", "/"));
			}
			version(Windows) {
			this.outputPath = buildNormalizedPath(projectRoot, root.expectAttributeValue!string("outputPath").replace("/", "\\"));
			}
		} catch (Exception ex) { }
		foreach(sop; root.getNodeValues("serializers")) {
			this.serializers ~= to!CSharpSerializers(sop.value!string());
		}
	}

	public bool hasSerializer(CSharpSerializers serializer) {
		return serializers.any!(a => a == serializer);
	}

	public void writeFile(StringBuilder builder, string schemaName, string fileName = string.init) {
		if (outputMode == CSharpOutputMode.FilePerObject && fileName != string.init) {
			string outDir = buildNormalizedPath(outputPath, schemaName);
			if(!exists(outDir)) {
				mkdirRecurse(outDir);
			}

			string op = setExtension(buildNormalizedPath(outDir, fileName.uppercaseFirst()), ".cs");
			writeln("Output:\t" ~ op);
			auto fsfile = File(op, "w");
			fsfile.write(builder);
			fsfile.close();
		} else {
			string outDir = buildNormalizedPath(outputPath);
			if(!exists(outDir)) {
				mkdirRecurse(outDir);
			}

			string op = setExtension(buildNormalizedPath(outDir, schemaName.uppercaseFirst()), ".cs");
			writeln("Output:\t" ~ op);
			auto fsfile = File(op, "w");
			fsfile.write(builder);
			fsfile.close();
		}
	}

	public void cleanFiles() {
		writeln("Clean:\t" ~ buildNormalizedPath(outputPath));
		auto rfFiles = dirEntries(buildNormalizedPath(outputPath), SpanMode.depth).filter!(f => f.name.endsWith(".cs"));
		foreach(rf; rfFiles) {
			if (readText(rf).canFind("[System.CodeDom.Compiler.GeneratedCode(\"EllipticBit.Coalescence.Generator\", ")) {
				std.file.remove(rf);
			}
		}
	}
}

public final class AspNetCoreHttpExtension : LanguageExtensionBase
{
    public immutable HttpService parent;
    public immutable string area = string.init;

    public @property bool hasArea() { return area != null && area != string.init; }
    public @property immutable(AspNetCoreAuthorizationExtension) getAuthorization() { return cast(immutable(AspNetCoreAuthorizationExtension))super.authorization; }

    public this(HttpService parent, SDLNode root) {
        this.parent = cast(immutable(HttpService))parent;
        this.area = root.getAttributeValue!string("area", string.init).strip().strip("/");

        auto authTag = root.getNode("authorization");
        auto auth = !authTag.isNull() ? new AspNetCoreAuthorizationExtension(this, authTag.get()) : new AspNetCoreAuthorizationExtension(this);

        super("csharp", "aspnetcore", auth);
    }

    public this(HttpService parent) {
        this.parent = cast(immutable(HttpService))parent;

        super("csharp", "aspnetcore", new AspNetCoreAuthorizationExtension(this));
    }
}

public AspNetCoreHttpExtension getAspNetCoreHttpExtension(HttpService service) {
    foreach (ext; service.extensions) {
        if (ext.framework.toLower() == "aspnetcore".toLower()) {
            return cast(AspNetCoreHttpExtension)ext;
        }
    }

    return new AspNetCoreHttpExtension(service);
}

public final class AspNetCoreHttpMethodExtension : LanguageExtensionBase
{
    public immutable HttpServiceMethod parent;
    public immutable string area = string.init;
    public immutable bool sync = false;

    public @property bool hasArea() { return area != null && area != string.init; }
    public @property immutable(AspNetCoreAuthorizationExtension) getAuthorization() { return cast(immutable(AspNetCoreAuthorizationExtension))super.authorization; }

    public this(HttpServiceMethod parent, SDLNode root) {
        this.parent = cast(immutable(HttpServiceMethod))parent;

        this.area = root.getAttributeValue!string("area", string.init).strip().strip("/");
        this.sync = root.getAttributeValue!bool("sync", false);

        auto authTag = root.getNode("authorization");
        auto auth = !authTag.isNull() ? new AspNetCoreAuthorizationExtension(this, authTag.get()) : new AspNetCoreAuthorizationExtension(this);

        super("csharp", "aspnetcore", auth);
    }

    public this(HttpServiceMethod parent) {
        this.parent = cast(immutable(HttpServiceMethod))parent;

        super("csharp", "aspnetcore", new AspNetCoreAuthorizationExtension(this));
    }
}

public AspNetCoreHttpMethodExtension getAspNetCoreHttpExtension(HttpServiceMethod method) {
    foreach (ext; method.extensions) {
        if (ext.framework.toLower() == "aspnetcore".toLower()) {
            return cast(AspNetCoreHttpMethodExtension)ext;
        }
    }

    return new AspNetCoreHttpMethodExtension(method);
}

public final class AspNetCoreWebsocketExtension : LanguageExtensionBase
{
    public immutable WebsocketService parent;

	public string clientConnection = string.init;

    public @property immutable(AspNetCoreAuthorizationExtension) getAuthorization() { return cast(immutable(AspNetCoreAuthorizationExtension))super.authorization; }

    public this(WebsocketService parent, SDLNode root) {
        this.parent = cast(immutable(WebsocketService))parent;
		this.clientConnection = root.getAttributeValue!string("clientConnection", string.init);

        auto authTag = root.getNode("authorization");
        auto auth = !authTag.isNull() ? new AspNetCoreAuthorizationExtension(this, authTag.get()) : new AspNetCoreAuthorizationExtension(this);

        super("csharp", "aspnetcore", auth);
    }

	public this(WebsocketService parent) {
        this.parent = cast(immutable(WebsocketService))parent;

        super("csharp", "aspnetcore", new AspNetCoreAuthorizationExtension(this));
	}
}

public AspNetCoreWebsocketExtension getAspNetCoreWebsocketExtension(WebsocketService service) {
    foreach (ext; service.extensions) {
        if (ext.framework.toLower() == "aspnetcore".toLower()) {
            return cast(AspNetCoreWebsocketExtension)ext;
        }
    }

    return new AspNetCoreWebsocketExtension(service);
}

public final class AspNetCoreWebsocketMethodExtension : LanguageExtensionBase
{
    public immutable WebsocketServiceMethod parent;

    public @property immutable(AspNetCoreAuthorizationExtension) getAuthorization() { return cast(immutable(AspNetCoreAuthorizationExtension))super.authorization; }

    public this(WebsocketServiceMethod parent, SDLNode root) {
        this.parent = cast(immutable(WebsocketServiceMethod))parent;

        auto authTag = root.getNode("authorization");
        auto auth = !authTag.isNull() ? new AspNetCoreAuthorizationExtension(this, authTag.get()) : new AspNetCoreAuthorizationExtension(this);

        super("csharp", "aspnetcore", auth);
    }

    public this(WebsocketServiceMethod parent) {
        this.parent = cast(immutable(WebsocketServiceMethod))parent;

        super("csharp", "aspnetcore", new AspNetCoreAuthorizationExtension(this));
    }
}

public AspNetCoreWebsocketMethodExtension getAspNetCoreWebsocketMethodExtension(WebsocketServiceMethod service) {
    foreach (ext; service.extensions) {
        if (ext.framework.toLower() == "aspnetcore".toLower()) {
            return cast(AspNetCoreWebsocketMethodExtension)ext;
        }
    }

    return new AspNetCoreWebsocketMethodExtension(service);
}

public final class AspNetCoreAuthorizationExtension : AuthorizationExtensionBase
{
	public LanguageExtensionBase parent;
    public string policy = string.init;
    public string[] schemes;
    public string[] roles;
    public bool requireAllRoles = false;

    public this(LanguageExtensionBase parent, SDLNode root) {
		this.parent = parent;
		requireAllRoles = root.getAttributeValue!bool("allRoles", false);
        policy = root.getAttributeValue!string("policy", null);

        auto st = root.getAttributeValue!string("schemes", null);
        if (st !is null) {
            foreach(s; st.split(',')) {
                schemes ~= s;
            }
        }

        auto rt = root.getAttributeValue!string("roles", null);
        if (rt !is null) {
            foreach(r; rt.split(',')) {
                roles ~= r;
            }
        }
    }

    public this(LanguageExtensionBase parent) {
		this.parent = parent;
	}
}
