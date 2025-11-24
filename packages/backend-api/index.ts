import PocketBase, { BaseAuthStore } from "pocketbase";
import type { TypedPocketBase } from "./pocketbase-types";

export const newApiClient = (
  baseURL?: string,
  authStore?: BaseAuthStore | null,
  lang?: string,
) => new PocketBase(baseURL, authStore, lang) as TypedPocketBase;

export * from "./pocketbase-types";
