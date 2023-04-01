module restforge.languages.csharp.aspnetcore.extensions;

import restforge.model;

import std.algorithm.iteration;
import std.algorithm.searching;
import std.array;
import std.conv;
import std.typecons;
import std.stdio;
import std.string;

import sdlang;

public final class AspNetCoreHttpExtension : LanguageExtensionBase
{
    public immutable HttpService parent;
    public immutable string area = string.init;

    public @property bool hasArea() { return area != null && area != string.init; }
    public @property immutable(AspNetCoreAuthorizationExtension) getAuthorization() { return cast(immutable(AspNetCoreAuthorizationExtension))super.authorization; }

    public this(HttpService parent, Tag root) {
        this.parent = cast(immutable(HttpService))parent;
        this.area = root.getAttribute!string("area", string.init).strip().strip("/");

        auto authTag = root.getTag("authorization", null);
        auto auth = authTag !is null ? new AspNetCoreAuthorizationExtension(this, authTag) : new AspNetCoreAuthorizationExtension(this);

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

    public this(HttpServiceMethod parent, Tag root) {
        this.parent = cast(immutable(HttpServiceMethod))parent;

        this.area = root.getAttribute!string("area", string.init).strip().strip("/");
        this.sync = root.getAttribute!bool("sync", false);

        auto authTag = root.getTag("authorization", null);
        auto auth = authTag !is null ? new AspNetCoreAuthorizationExtension(this, authTag) : new AspNetCoreAuthorizationExtension(this);

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

    public this(WebsocketService parent, Tag root) {
        this.parent = cast(immutable(WebsocketService))parent;
		this.clientConnection = root.getAttribute!string("clientConnection", string.init);

        auto authTag = root.getTag("authorization", null);
        auto auth = authTag !is null ? new AspNetCoreAuthorizationExtension(this, authTag) : new AspNetCoreAuthorizationExtension(this);

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

    public this(WebsocketServiceMethod parent, Tag root) {
        this.parent = cast(immutable(WebsocketServiceMethod))parent;

        auto authTag = root.getTag("authorization", null);
        auto auth = authTag !is null ? new AspNetCoreAuthorizationExtension(this, authTag) : new AspNetCoreAuthorizationExtension(this);

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

    public this(LanguageExtensionBase parent, Tag root) {
		this.parent = parent;
		requireAllRoles = root.getAttribute!bool("allRoles", false);
        policy = root.getAttribute!string("policy", null);

        auto st = root.getAttribute!string("schemes", null);
        if (st !is null) {
            foreach(s; st.split(',')) {
                schemes ~= s;
            }
        }

        auto rt = root.getAttribute!string("roles", null);
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
