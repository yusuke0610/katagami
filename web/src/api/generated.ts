/**
 * 自動生成ファイル — 手編集禁止。
 *
 * backend の FastAPI OpenAPI スキーマから openapi-typescript で生成される。
 * 再生成: `make codegen-types`。
 * backend の Pydantic schema が DTO の Single Source of Truth であり、
 * このファイルはその機械的ミラー。直接編集しても次回生成で上書きされる。
 */
export interface paths {
    "/health": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        /** Health */
        get: operations["health_health_get"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
}
export type webhooks = Record<string, never>;
export interface components {
    schemas: {
        /**
         * HealthResponse
         * @description ヘルスチェック応答。
         *
         *     schemas/ 配下の Pydantic モデルは OpenAPI スキーマとして書き出され、
         *     web の型（src/api/generated.ts）の正本になる。フィールドを変更したら
         *     `make codegen-types` で再生成してコミットすること（CI の codegen-drift が検証）。
         */
        HealthResponse: {
            /** Status */
            status: string;
            /** Version */
            version: string;
        };
    };
    responses: never;
    parameters: never;
    requestBodies: never;
    headers: never;
    pathItems: never;
}
export type $defs = Record<string, never>;
export interface operations {
    health_health_get: {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description Successful Response */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": components["schemas"]["HealthResponse"];
                };
            };
        };
    };
}
