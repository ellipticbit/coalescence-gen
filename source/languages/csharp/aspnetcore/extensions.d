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
    public immutable string area;

    public @property bool hasArea() { return area != null && area != string.init; }
    public @property immutable(AspNetCoreAuthorizationExtension) getAuthorization() { return cast(immutable(AspNetCoreAuthorizationExtension))super.authorization; }

    public this(HttpService parent, Tag root) {
        this.parent = cast(immutable(HttpService))parent;
        this.area = root.getAttribute!string("area", string.init).strip().strip("/");

        auto authTag = root.getTag("authorization", null);
        auto auth = authTag !is null ? new AspNetCoreAuthorizationExtension(this, authTag) : null;

        super("csharp", "aspnetcore", auth);
    }
}

public AspNetCoreHttpExtension getAspNetCoreHttpExtension(HttpService service) {
    foreach (ext; service.extensions) {
        if (ext.framework.toLower() == "aspnetcore".toLower()) {
            return cast(AspNetCoreHttpExtension)ext;
        }
    }

    return null;
}

public final class AspNetCoreHttpMethodExtension : LanguageExtensionBase
{
    public immutable HttpServiceMethod parent;
    public immutable string area;
    public immutable bool sync;

    public @property bool hasArea() { return area != null && area != string.init; }
    public @property immutable(AspNetCoreAuthorizationExtension) getAuthorization() { return cast(immutable(AspNetCoreAuthorizationExtension))super.authorization; }

    public this(HttpServiceMethod parent, Tag root) {
        this.parent = cast(immutable(HttpServiceMethod))parent;

        this.area = root.getAttribute!string("area", string.init).strip().strip("/");
        this.sync = root.getAttribute!bool("sync", false);

        auto authTag = root.getTag("authorization", null);
        auto auth = authTag !is null ? new AspNetCoreAuthorizationExtension(this, authTag) : null;

        super("csharp", "aspnetcore", auth);
    }
}

public AspNetCoreHttpMethodExtension getAspNetCoreHttpExtension(HttpServiceMethod method) {
    foreach (ext; method.extensions) {
        if (ext.framework.toLower() == "aspnetcore".toLower()) {
            return cast(AspNetCoreHttpMethodExtension)ext;
        }
    }

    return null;
}

public final class AspNetCoreWebsocketExtension : LanguageExtensionBase
{
    public immutable WebsocketService parent;

    public @property immutable(AspNetCoreAuthorizationExtension) getAuthorization() { return cast(immutable(AspNetCoreAuthorizationExtension))super.authorization; }

    public this(WebsocketService parent, Tag root) {
        this.parent = cast(immutable(WebsocketService))parent;

        auto authTag = root.getTag("authorization", null); 
        auto auth = authTag !is null ? new AspNetCoreAuthorizationExtension(this, authTag) : null;

        super("csharp", "aspnetcore", auth);
    }
}

public AspNetCoreWebsocketExtension getAspNetCoreWebsocketExtension(WebsocketService service) {
    foreach (ext; service.extensions) {
        if (ext.framework.toLower() == "aspnetcore".toLower()) {
            return cast(AspNetCoreWebsocketExtension)ext;
        }
    }

    return null;
}

public final class AspNetCoreWebsocketMethodExtension : LanguageExtensionBase
{
    public immutable WebsocketServiceMethod parent;

    public immutable bool sync;

    public @property immutable(AspNetCoreAuthorizationExtension) getAuthorization() { return cast(immutable(AspNetCoreAuthorizationExtension))super.authorization; }

    public this(WebsocketServiceMethod parent, Tag root) {
        this.parent = cast(immutable(WebsocketServiceMethod))parent;
        this.sync = root.getAttribute!bool("sync", false);

        auto authTag = root.getTag("authorization", null); 
        auto auth = authTag !is null ? new AspNetCoreAuthorizationExtension(this, authTag) : null;

        super("csharp", "aspnetcore", auth);
    }
}

public AspNetCoreWebsocketMethodExtension getAspNetCoreWebsocketMethodExtension(WebsocketServiceMethod service) {
    foreach (ext; service.extensions) {
        if (ext.framework.toLower() == "aspnetcore".toLower()) {
            return cast(AspNetCoreWebsocketMethodExtension)ext;
        }
    }

    return null;
}

public final class AspNetCoreAuthorizationExtension : AuthorizationExtensionBase
{
    public string policy;
    public string[] schemes;
    public string[] roles;
    public bool requireAllRoles;

    public this(LanguageExtensionBase parent, Tag root) {
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
}
