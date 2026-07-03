// CZID-284 — minimal, dependency-free Secrets Manager reader for Lambda@Edge.
//
// WHY stdlib-only: a viewer-request Lambda@Edge has a hard 1 MB code+deps limit, so we cannot ship the
// AWS SDK (@aws-sdk/client-secrets-manager is ~1 MB+ on its own). Instead we sign a single
// GetSecretValue call with SigV4 using only node:crypto + node:https. This is the standard tiny-edge
// pattern. The execution role (main.tf) grants secretsmanager:GetSecretValue scoped to the one ARN.
//
// CREDENTIALS: at runtime the Lambda execution-role credentials arrive via the standard container
// env vars (AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY / AWS_SESSION_TOKEN). NOTE: those are the *role*
// credentials injected by the Lambda runtime, NOT application config — Lambda@Edge forbids only
// USER-defined env vars; the runtime's own credential vars are still present. Reading them here is the
// only supported way to sign, and is distinct from baking config (which we do in config.mjs).
//
// FAIL-CLOSED: every error path throws; the caller (adapter → handler) turns any throw into a 403.

import https from "node:https";
import crypto from "node:crypto";

const SERVICE = "secretsmanager";

function hmac(key, data) {
  return crypto.createHmac("sha256", key).update(data, "utf8").digest();
}
function sha256Hex(data) {
  return crypto.createHash("sha256").update(data, "utf8").digest("hex");
}

// Derive the SigV4 signing key for the request date/region/service.
function signingKey(secretKey, dateStamp, region) {
  const kDate = hmac("AWS4" + secretKey, dateStamp);
  const kRegion = hmac(kDate, region);
  const kService = hmac(kRegion, SERVICE);
  return hmac(kService, "aws4_request");
}

// Perform one signed POST to Secrets Manager's GetSecretValue and return the parsed JSON body.
// timeoutMs bounds the whole call so the viewer-request budget is respected (fail-closed on timeout).
export function getSecretValue(secretId, region, timeoutMs = 1500) {
  return new Promise((resolve, reject) => {
    const accessKey = process.env.AWS_ACCESS_KEY_ID;
    const secretKey = process.env.AWS_SECRET_ACCESS_KEY;
    const sessionToken = process.env.AWS_SESSION_TOKEN;
    if (!accessKey || !secretKey) {
      return reject(new Error("secretsmanager: no runtime credentials"));
    }

    const host = `${SERVICE}.${region}.amazonaws.com`;
    const body = JSON.stringify({ SecretId: secretId });
    const now = new Date();
    const amzDate = now.toISOString().replace(/[:-]|\.\d{3}/g, ""); // YYYYMMDDTHHMMSSZ
    const dateStamp = amzDate.slice(0, 8);
    const target = "secretsmanager.GetSecretValue";
    const contentType = "application/x-amz-json-1.1";

    // --- Canonical request ---
    const canonicalHeaders =
      `content-type:${contentType}\n` +
      `host:${host}\n` +
      `x-amz-date:${amzDate}\n` +
      `x-amz-target:${target}\n`;
    const signedHeaders = "content-type;host;x-amz-date;x-amz-target";
    const canonicalRequest = [
      "POST",
      "/",
      "",
      canonicalHeaders,
      signedHeaders,
      sha256Hex(body),
    ].join("\n");

    // --- String to sign ---
    const scope = `${dateStamp}/${region}/${SERVICE}/aws4_request`;
    const stringToSign = [
      "AWS4-HMAC-SHA256",
      amzDate,
      scope,
      sha256Hex(canonicalRequest),
    ].join("\n");

    // --- Signature + Authorization header ---
    const signature = crypto
      .createHmac("sha256", signingKey(secretKey, dateStamp, region))
      .update(stringToSign, "utf8")
      .digest("hex");
    const authorization =
      `AWS4-HMAC-SHA256 Credential=${accessKey}/${scope}, ` +
      `SignedHeaders=${signedHeaders}, Signature=${signature}`;

    const headers = {
      "Content-Type": contentType,
      "X-Amz-Date": amzDate,
      "X-Amz-Target": target,
      Authorization: authorization,
      "Content-Length": Buffer.byteLength(body),
    };
    if (sessionToken) headers["X-Amz-Security-Token"] = sessionToken;

    const req = https.request(
      { host, method: "POST", path: "/", headers, timeout: timeoutMs },
      (res) => {
        let data = "";
        res.on("data", (c) => (data += c));
        res.on("end", () => {
          if (res.statusCode !== 200) {
            return reject(new Error(`secretsmanager ${res.statusCode}`));
          }
          try {
            resolve(JSON.parse(data));
          } catch (e) {
            reject(new Error("secretsmanager: malformed response"));
          }
        });
      },
    );
    req.on("timeout", () => req.destroy(new Error("secretsmanager: timeout")));
    req.on("error", reject);
    req.write(body);
    req.end();
  });
}
