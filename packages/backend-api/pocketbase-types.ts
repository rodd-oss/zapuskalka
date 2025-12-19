/**
 * PocketBase TypeScript Types
 * Auto-generated - DO NOT EDIT
 */

import PocketBase, {
    RecordService,
    type ListResult,
    type RecordSubscription,
    type UnsubscribeFunc,
    type RecordOptions,
    type RecordListOptions,
    type RecordFullListOptions,
    type RecordSubscribeOptions,
} from 'pocketbase';

export type RecordIdString = string & { readonly __recordId: unique symbol };
export type AutodateString = string & { readonly __autodate: unique symbol };
export type HTMLString = string & { readonly __html: unique symbol };
export type Email = string & { readonly __email: unique symbol };
export type URL = string & { readonly __url: unique symbol };

export interface GeoPoint {
    lat: number;
    lon: number;
};

export interface BaseSystemFields {
    id: RecordIdString;
    created: AutodateString;
    updated: AutodateString;
};

export interface AuthSystemFields {
    email: Email;
    emailVisibility: boolean;
    verified: boolean;
};

export type SystemFields = keyof BaseSystemFields | 'collectionId' | 'collectionName' | 'expand';

export type RecordCreate<T> = Omit<T, SystemFields> & { id?: string };
export type RecordUpdate<T> = Partial<Omit<T, SystemFields>>;

export const Collections = {
    Authcode: "_authCode",
    Authorigins: "_authOrigins",
    Externalauths: "_externalAuths",
    Mfas: "_mfas",
    Otps: "_otps",
    Superusers: "_superusers",
    AppBranches: "app_branches",
    AppBuilds: "app_builds",
    Apps: "apps",
    AvBuildChecks: "av_build_checks",
    Publishers: "publishers",
    Users: "users",
} as const;

export type Collections = typeof Collections[keyof typeof Collections];

export const AppBuildsOsValues = {
    Windows: "windows",
    Linux: "linux",
    Macos: "macos",
} as const;

export type AppBuildsOsOptions = typeof AppBuildsOsValues[keyof typeof AppBuildsOsValues];

export const AppBuildsArchValues = {
    X8664: "x86_64",
    Arm: "arm",
    Aarch64: "aarch64",
    Universal: "universal",
    X86: "x86",
    Mips: "mips",
    Mips64: "mips64",
    Powerpc: "powerpc",
    Powerpc64: "powerpc64",
    Riscv64: "riscv64",
    S390x: "s390x",
    Sparc64: "sparc64",
} as const;

export type AppBuildsArchOptions = typeof AppBuildsArchValues[keyof typeof AppBuildsArchValues];

export const AppBuildsInstallRulesValues = {
    DirectCopy: "direct_copy",
    Untar: "untar",
    Ungzip: "ungzip",
    Unzip: "unzip",
} as const;

export type AppBuildsInstallRulesOptions = typeof AppBuildsInstallRulesValues[keyof typeof AppBuildsInstallRulesValues];

export const AvBuildChecksStatusValues = {
    Pending: "pending",
    Scanning: "scanning",
    Clean: "clean",
    Infected: "infected",
    Error: "error",
} as const;

export type AvBuildChecksStatusOptions = typeof AvBuildChecksStatusValues[keyof typeof AvBuildChecksStatusValues];

export interface AuthcodeRecord {
    user: RecordIdString;
};

export interface AuthoriginsRecord {
    collectionRef: string;
    recordRef: string;
    fingerprint: string;
};

export interface ExternalauthsRecord {
    collectionRef: string;
    recordRef: string;
    provider: string;
    providerId: string;
};

export interface MfasRecord {
    collectionRef: string;
    recordRef: string;
    method: string;
};

export interface OtpsRecord {
    collectionRef: string;
    recordRef: string;
    sentTo?: string;
};

export interface SuperusersRecord {
};

export interface AppBranchesRecord {
    app: RecordIdString;
    name: string;
};

export interface AppBuildsRecord {
    files?: string[];
    branch: RecordIdString;
    app: RecordIdString;
    os: AppBuildsOsOptions;
    arch: AppBuildsArchOptions;
    install_rules: AppBuildsInstallRulesOptions[];
    entrypoint: string;
};

export interface AppsRecord {
    title: string;
    publisher: RecordIdString;
    default_branch?: RecordIdString;
};

export interface AvBuildChecksRecord {
    build: RecordIdString;
    status: AvBuildChecksStatusOptions;
    virus_name?: string;
    scan_time?: string;
    log?: string;
};

export interface PublishersRecord {
    title: string;
    users?: RecordIdString[];
    owner: RecordIdString;
};

export interface UsersRecord {
    name?: string;
    avatar?: string;
};

export interface AuthcodeResponse<Expand = {}> extends AuthcodeRecord, BaseSystemFields {
    collectionId: string;
    collectionName: "_authCode";
    expand?: Expand;
};

export interface AuthoriginsResponse<Expand = {}> extends AuthoriginsRecord, BaseSystemFields {
    collectionId: string;
    collectionName: "_authOrigins";
    expand?: Expand;
};

export interface ExternalauthsResponse<Expand = {}> extends ExternalauthsRecord, BaseSystemFields {
    collectionId: string;
    collectionName: "_externalAuths";
    expand?: Expand;
};

export interface MfasResponse<Expand = {}> extends MfasRecord, BaseSystemFields {
    collectionId: string;
    collectionName: "_mfas";
    expand?: Expand;
};

export interface OtpsResponse<Expand = {}> extends OtpsRecord, BaseSystemFields {
    collectionId: string;
    collectionName: "_otps";
    expand?: Expand;
};

export interface SuperusersResponse<Expand = {}> extends SuperusersRecord, BaseSystemFields, AuthSystemFields {
    collectionId: string;
    collectionName: "_superusers";
    expand?: Expand;
};

export interface AppBranchesResponse<Expand = {}> extends AppBranchesRecord, BaseSystemFields {
    collectionId: string;
    collectionName: "app_branches";
    expand?: Expand;
};

export interface AppBuildsResponse<Expand = {}> extends AppBuildsRecord, BaseSystemFields {
    collectionId: string;
    collectionName: "app_builds";
    expand?: Expand;
};

export interface AppsResponse<Expand = {}> extends AppsRecord, BaseSystemFields {
    collectionId: string;
    collectionName: "apps";
    expand?: Expand;
};

export interface AvBuildChecksResponse<Expand = {}> extends AvBuildChecksRecord, BaseSystemFields {
    collectionId: string;
    collectionName: "av_build_checks";
    expand?: Expand;
};

export interface PublishersResponse<Expand = {}> extends PublishersRecord, BaseSystemFields {
    collectionId: string;
    collectionName: "publishers";
    expand?: Expand;
};

export interface UsersResponse<Expand = {}> extends UsersRecord, BaseSystemFields, AuthSystemFields {
    collectionId: string;
    collectionName: "users";
    expand?: Expand;
};

export type AuthcodeRelations = {
    user: { response: UsersResponse; isMulti: false; collection: "users" };
};

export type AuthcodeBackRelations = {};

export type AuthoriginsRelations = {};

export type AuthoriginsBackRelations = {};

export type ExternalauthsRelations = {};

export type ExternalauthsBackRelations = {};

export type MfasRelations = {};

export type MfasBackRelations = {};

export type OtpsRelations = {};

export type OtpsBackRelations = {};

export type SuperusersRelations = {};

export type SuperusersBackRelations = {};

export type AppBranchesRelations = {
    app: { response: AppsResponse; isMulti: false; collection: "apps" };
};

export type AppBranchesBackRelations = {
    "app_builds_via_branch": { response: AppBuildsResponse; isMulti: true; collection: "app_builds" };
    "apps_via_default_branch": { response: AppsResponse; isMulti: true; collection: "apps" };
};

export type AppBuildsRelations = {
    branch: { response: AppBranchesResponse; isMulti: false; collection: "app_branches" };
    app: { response: AppsResponse; isMulti: false; collection: "apps" };
};

export type AppBuildsBackRelations = {
    "av_build_checks_via_build": { response: AvBuildChecksResponse; isMulti: true; collection: "av_build_checks" };
};

export type AppsRelations = {
    publisher: { response: PublishersResponse; isMulti: false; collection: "publishers" };
    default_branch: { response: AppBranchesResponse; isMulti: false; collection: "app_branches" };
};

export type AppsBackRelations = {
    "app_branches_via_app": { response: AppBranchesResponse; isMulti: true; collection: "app_branches" };
    "app_builds_via_app": { response: AppBuildsResponse; isMulti: true; collection: "app_builds" };
};

export type AvBuildChecksRelations = {
    build: { response: AppBuildsResponse; isMulti: false; collection: "app_builds" };
};

export type AvBuildChecksBackRelations = {};

export type PublishersRelations = {
    users: { response: UsersResponse; isMulti: true; collection: "users" };
    owner: { response: UsersResponse; isMulti: false; collection: "users" };
};

export type PublishersBackRelations = {
    "apps_via_publisher": { response: AppsResponse; isMulti: true; collection: "apps" };
};

export type UsersRelations = {};

export type UsersBackRelations = {
    "_authCode_via_user": { response: AuthcodeResponse; isMulti: true; collection: "_authCode" };
    "publishers_via_owner": { response: PublishersResponse; isMulti: true; collection: "publishers" };
    "publishers_via_users": { response: PublishersResponse; isMulti: true; collection: "publishers" };
};

export type AuthcodeCreate = AuthcodeRecord & { id?: string };

export type AuthoriginsCreate = AuthoriginsRecord & { id?: string };

export type ExternalauthsCreate = ExternalauthsRecord & { id?: string };

export type MfasCreate = MfasRecord & { id?: string };

export type OtpsCreate = OtpsRecord & { id?: string };

export type SuperusersCreate = SuperusersRecord & {
    id?: string;
    email: string;
    password: string;
    passwordConfirm?: string;
};

export type AppBranchesCreate = AppBranchesRecord & { id?: string };

export type AppBuildsCreate = AppBuildsRecord & { id?: string };

export type AppsCreate = AppsRecord & { id?: string };

export type AvBuildChecksCreate = AvBuildChecksRecord & { id?: string };

export type PublishersCreate = PublishersRecord & { id?: string };

export type UsersCreate = UsersRecord & {
    id?: string;
    email: string;
    password: string;
    passwordConfirm?: string;
};

export type AuthcodeUpdate = Partial<AuthcodeRecord>;

export type AuthoriginsUpdate = Partial<AuthoriginsRecord>;

export type ExternalauthsUpdate = Partial<ExternalauthsRecord>;

export type MfasUpdate = Partial<MfasRecord>;

export type OtpsUpdate = Partial<OtpsRecord>;

export type SuperusersUpdate = Partial<SuperusersRecord> & {
    email?: string;
    password?: string;
    passwordConfirm?: string;
    oldPassword?: string;
};

export type AppBranchesUpdate = Partial<AppBranchesRecord>;

export type AppBuildsUpdate = Partial<AppBuildsRecord>;

export type AppsUpdate = Partial<AppsRecord>;

export type AvBuildChecksUpdate = Partial<AvBuildChecksRecord>;

export type PublishersUpdate = Partial<PublishersRecord>;

export type UsersUpdate = Partial<UsersRecord> & {
    email?: string;
    password?: string;
    passwordConfirm?: string;
    oldPassword?: string;
};

export type AllResponses = AuthcodeResponse | AuthoriginsResponse | ExternalauthsResponse | MfasResponse | OtpsResponse | SuperusersResponse | AppBranchesResponse | AppBuildsResponse | AppsResponse | AvBuildChecksResponse | PublishersResponse | UsersResponse;

export type CollectionNames = "_authCode" | "_authOrigins" | "_externalAuths" | "_mfas" | "_otps" | "_superusers" | "app_branches" | "app_builds" | "apps" | "av_build_checks" | "publishers" | "users";

export type CollectionRecords = {
    "_authCode": AuthcodeRecord;
    "_authOrigins": AuthoriginsRecord;
    "_externalAuths": ExternalauthsRecord;
    "_mfas": MfasRecord;
    "_otps": OtpsRecord;
    "_superusers": SuperusersRecord;
    "app_branches": AppBranchesRecord;
    "app_builds": AppBuildsRecord;
    "apps": AppsRecord;
    "av_build_checks": AvBuildChecksRecord;
    "publishers": PublishersRecord;
    "users": UsersRecord;
};

export type CollectionResponses = {
    "_authCode": AuthcodeResponse;
    "_authOrigins": AuthoriginsResponse;
    "_externalAuths": ExternalauthsResponse;
    "_mfas": MfasResponse;
    "_otps": OtpsResponse;
    "_superusers": SuperusersResponse;
    "app_branches": AppBranchesResponse;
    "app_builds": AppBuildsResponse;
    "apps": AppsResponse;
    "av_build_checks": AvBuildChecksResponse;
    "publishers": PublishersResponse;
    "users": UsersResponse;
};

export type CollectionCreates = {
    "_authCode": AuthcodeCreate;
    "_authOrigins": AuthoriginsCreate;
    "_externalAuths": ExternalauthsCreate;
    "_mfas": MfasCreate;
    "_otps": OtpsCreate;
    "_superusers": SuperusersCreate;
    "app_branches": AppBranchesCreate;
    "app_builds": AppBuildsCreate;
    "apps": AppsCreate;
    "av_build_checks": AvBuildChecksCreate;
    "publishers": PublishersCreate;
    "users": UsersCreate;
};

export type CollectionUpdates = {
    "_authCode": AuthcodeUpdate;
    "_authOrigins": AuthoriginsUpdate;
    "_externalAuths": ExternalauthsUpdate;
    "_mfas": MfasUpdate;
    "_otps": OtpsUpdate;
    "_superusers": SuperusersUpdate;
    "app_branches": AppBranchesUpdate;
    "app_builds": AppBuildsUpdate;
    "apps": AppsUpdate;
    "av_build_checks": AvBuildChecksUpdate;
    "publishers": PublishersUpdate;
    "users": UsersUpdate;
};

export type CollectionRelations = {
    "_authCode": AuthcodeRelations;
    "_authOrigins": AuthoriginsRelations;
    "_externalAuths": ExternalauthsRelations;
    "_mfas": MfasRelations;
    "_otps": OtpsRelations;
    "_superusers": SuperusersRelations;
    "app_branches": AppBranchesRelations;
    "app_builds": AppBuildsRelations;
    "apps": AppsRelations;
    "av_build_checks": AvBuildChecksRelations;
    "publishers": PublishersRelations;
    "users": UsersRelations;
};

export type CollectionBackRelations = {
    "_authCode": AuthcodeBackRelations;
    "_authOrigins": AuthoriginsBackRelations;
    "_externalAuths": ExternalauthsBackRelations;
    "_mfas": MfasBackRelations;
    "_otps": OtpsBackRelations;
    "_superusers": SuperusersBackRelations;
    "app_branches": AppBranchesBackRelations;
    "app_builds": AppBuildsBackRelations;
    "apps": AppsBackRelations;
    "av_build_checks": AvBuildChecksBackRelations;
    "publishers": PublishersBackRelations;
    "users": UsersBackRelations;
};

type Split<S extends string, D extends string = ","> = 
    string extends S ? string[] :
    S extends "" ? [] :
    S extends `${infer T}${D}${infer U}` ? [T, ...Split<U, D>] : [S];

type TrimLeft<S extends string> = S extends ` ${infer R}` ? TrimLeft<R> : S;
type TrimRight<S extends string> = S extends `${infer L} ` ? TrimRight<L> : S;
type Trim<S extends string> = TrimLeft<TrimRight<S>>;

type SplitPath<S extends string> = 
    S extends `${infer Head}.${infer Tail}` ? [Head, ...SplitPath<Tail>] : [S];

type GetFirstPathSegment<S extends string> = 
    S extends `${infer Head}.${infer _Tail}` ? Head : S;

type GetRelationInfo<C extends Collections, F extends string> = 
    Trim<F> extends keyof CollectionRelations[C] 
        ? CollectionRelations[C][Trim<F>]
        : Trim<F> extends keyof CollectionBackRelations[C]
            ? CollectionBackRelations[C][Trim<F>]
            : { response: unknown; isMulti: false; collection: never };

type ResolveSimpleExpandField<C extends Collections, F extends string> = 
    GetRelationInfo<C, F> extends { response: infer R; isMulti: infer M }
        ? M extends true ? R[] : R
        : unknown;

type WithNestedExpand<T, NestedExpand> = 
    T extends object 
        ? Omit<T, 'expand'> & { expand?: NestedExpand }
        : T;

type ResolveNestedExpand<C extends Collections, Path extends string[]> =
    Path extends [infer First extends string, ...infer Rest extends string[]]
        ? GetRelationInfo<C, First> extends { response: infer R; isMulti: infer M; collection: infer NC }
            ? Rest extends []
                ? M extends true ? R[] : R
                : NC extends Collections
                    ? M extends true
                        ? WithNestedExpand<R, ResolveNestedExpand<NC, Rest>>[]
                        : WithNestedExpand<R, ResolveNestedExpand<NC, Rest>>
                    : unknown
            : unknown
        : {};

type ResolveExpandField<C extends Collections, F extends string> = 
    F extends `${infer _Head}.${infer _Tail}`
        ? ResolveNestedExpand<C, SplitPath<Trim<F>>>
        : ResolveSimpleExpandField<C, F>;

type BuildExpandFromList<C extends Collections, L extends string[]> = 
    L extends [] ? {} :
    L extends [infer First extends string, ...infer Rest extends string[]] 
        ? { [K in Trim<GetFirstPathSegment<First>>]?: ResolveExpandField<C, First> } & BuildExpandFromList<C, Rest>
        : {};

type InferExpand<C extends Collections, E extends string> = 
    E extends "" ? {} : 
    BuildExpandFromList<C, Split<E, ",">>;

export function isAuthcodeResponse(record: AllResponses): record is AuthcodeResponse {
    return record.collectionName === "_authCode";
}

export function isAuthoriginsResponse(record: AllResponses): record is AuthoriginsResponse {
    return record.collectionName === "_authOrigins";
}

export function isExternalauthsResponse(record: AllResponses): record is ExternalauthsResponse {
    return record.collectionName === "_externalAuths";
}

export function isMfasResponse(record: AllResponses): record is MfasResponse {
    return record.collectionName === "_mfas";
}

export function isOtpsResponse(record: AllResponses): record is OtpsResponse {
    return record.collectionName === "_otps";
}

export function isSuperusersResponse(record: AllResponses): record is SuperusersResponse {
    return record.collectionName === "_superusers";
}

export function isAppBranchesResponse(record: AllResponses): record is AppBranchesResponse {
    return record.collectionName === "app_branches";
}

export function isAppBuildsResponse(record: AllResponses): record is AppBuildsResponse {
    return record.collectionName === "app_builds";
}

export function isAppsResponse(record: AllResponses): record is AppsResponse {
    return record.collectionName === "apps";
}

export function isAvBuildChecksResponse(record: AllResponses): record is AvBuildChecksResponse {
    return record.collectionName === "av_build_checks";
}

export function isPublishersResponse(record: AllResponses): record is PublishersResponse {
    return record.collectionName === "publishers";
}

export function isUsersResponse(record: AllResponses): record is UsersResponse {
    return record.collectionName === "users";
}

export type RecordOptionsWithExpand<E extends string = ""> = Omit<RecordOptions, 'expand'> & { expand?: E };
export type RecordListOptionsWithExpand<E extends string = ""> = Omit<RecordListOptions, 'expand'> & { expand?: E };
export type RecordFullListOptionsWithExpand<E extends string = ""> = Omit<RecordFullListOptions, 'expand'> & { expand?: E };
export type RecordSubscribeOptionsWithExpand<E extends string = ""> = Omit<RecordSubscribeOptions, 'expand'> & { expand?: E };

export type WithExpand<T, E> = Omit<T, 'expand'> & { expand?: E };

export interface TypedRecordService<C extends Collections> {
    getOne<E extends string = "">(
        id: string,
        options?: RecordOptionsWithExpand<E>
    ): Promise<WithExpand<CollectionResponses[C], InferExpand<C, E>>>;

    getList<E extends string = "">(
        page?: number,
        perPage?: number,
        options?: RecordListOptionsWithExpand<E>
    ): Promise<ListResult<WithExpand<CollectionResponses[C], InferExpand<C, E>>>>;

    getFirstListItem<E extends string = "">(
        filter: string,
        options?: RecordListOptionsWithExpand<E>
    ): Promise<WithExpand<CollectionResponses[C], InferExpand<C, E>>>;

    getFullList<E extends string = "">(
        options?: RecordFullListOptionsWithExpand<E>
    ): Promise<WithExpand<CollectionResponses[C], InferExpand<C, E>>[]>;

    create<E extends string = "">(
        bodyOrRecord: C extends keyof CollectionCreates ? CollectionCreates[C] | FormData : FormData,
        options?: RecordOptionsWithExpand<E>
    ): Promise<WithExpand<CollectionResponses[C], InferExpand<C, E>>>;

    update<E extends string = "">(
        id: string,
        bodyOrRecord: C extends keyof CollectionUpdates ? CollectionUpdates[C] | FormData : FormData,
        options?: RecordOptionsWithExpand<E>
    ): Promise<WithExpand<CollectionResponses[C], InferExpand<C, E>>>;

    subscribe<E extends string = "">(
        topic: string,
        callback: (data: RecordSubscription<WithExpand<CollectionResponses[C], InferExpand<C, E>>>) => void,
        options?: RecordSubscribeOptionsWithExpand<E>
    ): Promise<UnsubscribeFunc>;
};

export interface TypedPocketBase extends PocketBase {
    collection<C extends Collections>(idOrName: C): TypedRecordService<C> & RecordService<CollectionResponses[C]>;
    collection(idOrName: string): RecordService;
};
