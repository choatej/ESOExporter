# Security Policy

## Reporting a vulnerability

Please do not open a public issue for a security problem. Use GitHub's private
vulnerability reporting: open the **Security** tab of this repository and choose
**Report a vulnerability**.

Examples of what counts: a post-processor that executes code from a crafted
SavedVariables file, or a path-traversal bug in a file-writing tool.

## Supported versions

There are no releases yet. Once there are, the latest release is supported.

## Scope

ESOExporter runs as an ESO add-on (sandboxed by the game client) and as local
post-processing tools. Treat SavedVariables files from other people as
untrusted input.
