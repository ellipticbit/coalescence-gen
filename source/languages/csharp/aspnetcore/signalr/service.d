module restforge.languages.csharp.aspnetcore.signalr.service;

import restforge.types;
import restforge.model;
import restforge.globals;
import restforge.stringbuilder;

import restforge.languages.csharp.aspnetcore.generator;
import restforge.languages.csharp.aspnetcore.extensions;

import std.algorithm.iteration;
import std.algorithm.searching;
import std.array;
import std.conv;
import std.stdio;
import std.string;

public void generateWebsocket(StringBuilder builder, WebsocketService s, ushort tabLevel)
{
    auto ext = s.getAspNetCoreWebsocketExtension();

    builder.appendLine();
    builder.appendLine("{0}{2} interface I{1}Server", generateTabs(tabLevel), s.name, s.isPublic ? "public" : "internal");
    builder.appendLine("{0}{", generateTabs(tabLevel));
    foreach(m; s.server) {
        generateInterfaceMethod(builder, m, cast(ushort)(tabLevel+1));
    }
    builder.appendLine("{0}}", generateTabs(tabLevel));
    builder.appendLine();

    if (s.client.length != 0) {
        builder.appendLine("{0}{2} interface I{1}Client", generateTabs(tabLevel), s.name, s.isPublic ? "public" : "internal");
        builder.appendLine("{0}{", generateTabs(tabLevel));
        foreach(m; s.client) {
            generateInterfaceMethod(builder, m, cast(ushort)(tabLevel+1));
        }
        builder.appendLine("{0}}", generateTabs(tabLevel));
        builder.appendLine();
    }

    if (ext !is null) {
        if (s.enableAuth) {
            generateAuthorization(builder, ext !is null ? ext.getAuthorization() : null, tabLevel);
        } else {
            builder.appendLine("{0}[AllowAnonymous]", generateTabs(tabLevel));
        }
    }

    if (s.client.length != 0) {
        builder.appendLine("{0}{2} abstract class {1}HubBase : Hub<I{1}{3}>, I{1}{4}", generateTabs(tabLevel), s.name, s.isPublic ? "public" : "internal", serverGen ? "Client" : "Server", serverGen ? "Server" : "Client");
    } else {
        builder.appendLine("{0}{2} abstract class {1}HubBase : Hub, I{1}{3}", generateTabs(tabLevel), s.name, s.isPublic ? "public" : "internal", serverGen ? "Server" : "Client");
    }
    builder.appendLine("{0}{", generateTabs(tabLevel));
    foreach(m; s.server) {
        generateMethod(builder, m, cast(ushort)(tabLevel+1));
    }
    builder.appendLine("{0}}", generateTabs(tabLevel));
}

private void generateInterfaceMethod(StringBuilder builder, WebsocketServiceMethod sm, ushort tabLevel) {
    auto ext = sm.getAspNetCoreWebsocketMethodExtension();
    bool isSync = (ext !is null && ext.sync);

    if(!isSync) {
        builder.append("{0}Task", generateTabs(tabLevel));
        if(typeid(sm.returns.type) != typeid(TypeVoid)) {
            builder.append("<{0}>", generateType(sm.returns, false));
        }
    }
    else {
        builder.append("{0}{1}", generateTabs(tabLevel), generateType(sm.returns, false));
    }
    builder.append(" {0}(", cleanName(sm.name));
    generateMethodParameters(builder, sm.parameters);
    builder.appendLine(");");
}

private void generateMethod(StringBuilder builder, WebsocketServiceMethod sm, ushort tabLevel) {
    auto ext = sm.getAspNetCoreWebsocketMethodExtension();
    bool isSync = (ext !is null && ext.sync);

    if (ext !is null) {
        if (sm.enableAuth) {
            generateAuthorization(builder, ext !is null ? ext.getAuthorization() : null, tabLevel);
        } else {
            builder.appendLine("{0}[AllowAnonymous]", generateTabs(tabLevel));
        }
    }
    builder.append("{0}public abstract ", generateTabs(tabLevel));
    if(!isSync) {
        builder.append("Task", generateTabs(tabLevel));
        if(typeid(sm.returns.type) != typeid(TypeVoid)) {
            builder.append("<{0}>", generateType(sm.returns, false));
        }
    }
    else {
        builder.append("{0}{1}", generateTabs(tabLevel), generateType(sm.returns, false));
    }
    builder.append(" {0}(", cleanName(sm.name));
    generateMethodParameters(builder, sm.parameters);
    builder.appendLine(");");
}

private void generateMethodParameters(StringBuilder builder, TypeComplex[] smpl)
{
    bool hasParams = false;
    foreach (smp; smpl) {
        if (smp.type is null) continue;
        builder.append("{0} {1}, ", generateType(smp, false, true), cleanName(smp.name));
        hasParams = true;
    }

    if (hasParams) builder.removeRight(2);
}

private void generateAuthorization(StringBuilder builder, immutable(AspNetCoreAuthorizationExtension) auth, int tabLevel) {
    if (auth is null) {
        builder.appendLine("{0}[Authorize]", generateTabs(tabLevel));
    } else {
        if (auth.requireAllRoles) {
            foreach(r; auth.roles) {
                builder.appendLine("{0}[Authorize(Roles = \"{1}\")]", generateTabs(tabLevel), r);
            }
        } else {
            builder.appendLine("{0}[Authorize(Roles = \"{1}\")]", generateTabs(tabLevel), auth.roles.join(","));
        }
        if (auth.policy != string.init) {
            builder.appendLine("{0}[Authorize(Policy = \"{1}\")]", generateTabs(tabLevel), auth.policy);
        }
    }
}
