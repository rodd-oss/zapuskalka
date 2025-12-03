/**
* This file was @generated using pocketbase-typegen
*/

import type PocketBase from 'pocketbase'
import type { RecordService } from 'pocketbase'

export enum Collections {
	Authcode = "_authCode",
	Authorigins = "_authOrigins",
	Externalauths = "_externalAuths",
	Mfas = "_mfas",
	Otps = "_otps",
	Superusers = "_superusers",
	AppBranches = "app_branches",
	AppBuilds = "app_builds",
	Apps = "apps",
	Publishers = "publishers",
	Users = "users",
}

// Alias types for improved usability
export type IsoDateString = string
export type IsoAutoDateString = string & { readonly autodate: unique symbol }
export type RecordIdString = string
export type FileNameString = string & { readonly filename: unique symbol }
export type HTMLString = string

type ExpandType<T> = unknown extends T
	? T extends unknown
		? { expand?: unknown }
		: { expand: T }
	: { expand: T }

// System fields
export type BaseSystemFields<T = unknown> = {
	id: RecordIdString
	collectionId: string
	collectionName: Collections
} & ExpandType<T>

export type AuthSystemFields<T = unknown> = {
	email: string
	emailVisibility: boolean
	username: string
	verified: boolean
} & BaseSystemFields<T>

// Record types for each collection

export type AuthcodeRecord = {
	created: IsoAutoDateString
	id: string
	token: string
	updated: IsoAutoDateString
	user: RecordIdString
}

export type AuthoriginsRecord = {
	collectionRef: string
	created: IsoAutoDateString
	fingerprint: string
	id: string
	recordRef: string
	updated: IsoAutoDateString
}

export type ExternalauthsRecord = {
	collectionRef: string
	created: IsoAutoDateString
	id: string
	provider: string
	providerId: string
	recordRef: string
	updated: IsoAutoDateString
}

export type MfasRecord = {
	collectionRef: string
	created: IsoAutoDateString
	id: string
	method: string
	recordRef: string
	updated: IsoAutoDateString
}

export type OtpsRecord = {
	collectionRef: string
	created: IsoAutoDateString
	id: string
	password: string
	recordRef: string
	sentTo?: string
	updated: IsoAutoDateString
}

export type SuperusersRecord = {
	created: IsoAutoDateString
	email: string
	emailVisibility?: boolean
	id: string
	password: string
	tokenKey: string
	updated: IsoAutoDateString
	verified?: boolean
}

export type AppBranchesRecord = {
	app: RecordIdString
	created: IsoAutoDateString
	id: string
	name: string
	updated: IsoAutoDateString
}

export enum AppBuildsOsOptions {
	"windows" = "windows",
	"linux" = "linux",
	"macos" = "macos",
}

export enum AppBuildsArchOptions {
	"x86_64" = "x86_64",
	"arm" = "arm",
	"aarch64" = "aarch64",
	"universal" = "universal",
	"x86" = "x86",
	"mips" = "mips",
	"mips64" = "mips64",
	"powerpc" = "powerpc",
	"powerpc64" = "powerpc64",
	"riscv64" = "riscv64",
	"s390x" = "s390x",
	"sparc64" = "sparc64",
}

export enum AppBuildsInstallRulesOptions {
	"direct_copy" = "direct_copy",
	"untar" = "untar",
	"ungzip" = "ungzip",
	"unzip" = "unzip",
}
export type AppBuildsRecord = {
	app: RecordIdString
	arch: AppBuildsArchOptions
	branch: RecordIdString
	created: IsoAutoDateString
	entrypoint: string
	files?: FileNameString[]
	id: string
	install_rules: AppBuildsInstallRulesOptions[]
	os: AppBuildsOsOptions
	updated: IsoAutoDateString
}

export type AppsRecord = {
	created: IsoAutoDateString
	default_branch?: RecordIdString
	id: string
	publisher: RecordIdString
	title: string
	updated: IsoAutoDateString
}

export type PublishersRecord = {
	created: IsoAutoDateString
	id: string
	owner: RecordIdString
	title: string
	updated: IsoAutoDateString
	users?: RecordIdString[]
}

export type UsersRecord = {
	avatar?: FileNameString
	created: IsoAutoDateString
	email: string
	emailVisibility?: boolean
	id: string
	name?: string
	password: string
	tokenKey: string
	updated: IsoAutoDateString
	verified?: boolean
}

// Response types include system fields and match responses from the PocketBase API
export type AuthcodeResponse<Texpand = unknown> = Required<AuthcodeRecord> & BaseSystemFields<Texpand>
export type AuthoriginsResponse<Texpand = unknown> = Required<AuthoriginsRecord> & BaseSystemFields<Texpand>
export type ExternalauthsResponse<Texpand = unknown> = Required<ExternalauthsRecord> & BaseSystemFields<Texpand>
export type MfasResponse<Texpand = unknown> = Required<MfasRecord> & BaseSystemFields<Texpand>
export type OtpsResponse<Texpand = unknown> = Required<OtpsRecord> & BaseSystemFields<Texpand>
export type SuperusersResponse<Texpand = unknown> = Required<SuperusersRecord> & AuthSystemFields<Texpand>
export type AppBranchesResponse<Texpand = unknown> = Required<AppBranchesRecord> & BaseSystemFields<Texpand>
export type AppBuildsResponse<Texpand = unknown> = Required<AppBuildsRecord> & BaseSystemFields<Texpand>
export type AppsResponse<Texpand = unknown> = Required<AppsRecord> & BaseSystemFields<Texpand>
export type PublishersResponse<Texpand = unknown> = Required<PublishersRecord> & BaseSystemFields<Texpand>
export type UsersResponse<Texpand = unknown> = Required<UsersRecord> & AuthSystemFields<Texpand>

// Types containing all Records and Responses, useful for creating typing helper functions

export type CollectionRecords = {
	_authCode: AuthcodeRecord
	_authOrigins: AuthoriginsRecord
	_externalAuths: ExternalauthsRecord
	_mfas: MfasRecord
	_otps: OtpsRecord
	_superusers: SuperusersRecord
	app_branches: AppBranchesRecord
	app_builds: AppBuildsRecord
	apps: AppsRecord
	publishers: PublishersRecord
	users: UsersRecord
}

export type CollectionResponses = {
	_authCode: AuthcodeResponse
	_authOrigins: AuthoriginsResponse
	_externalAuths: ExternalauthsResponse
	_mfas: MfasResponse
	_otps: OtpsResponse
	_superusers: SuperusersResponse
	app_branches: AppBranchesResponse
	app_builds: AppBuildsResponse
	apps: AppsResponse
	publishers: PublishersResponse
	users: UsersResponse
}

// Utility types for create/update operations

type ProcessCreateAndUpdateFields<T> = Omit<{
	// Omit AutoDate fields
	[K in keyof T as Extract<T[K], IsoAutoDateString> extends never ? K : never]: 
		// Convert FileNameString to File
		T[K] extends infer U ? 
			U extends (FileNameString | FileNameString[]) ? 
				U extends any[] ? File[] : File 
			: U
		: never
}, 'id'>

// Create type for Auth collections
export type CreateAuth<T> = {
	id?: RecordIdString
	email: string
	emailVisibility?: boolean
	password: string
	passwordConfirm: string
	verified?: boolean
} & ProcessCreateAndUpdateFields<T>

// Create type for Base collections
export type CreateBase<T> = {
	id?: RecordIdString
} & ProcessCreateAndUpdateFields<T>

// Update type for Auth collections
export type UpdateAuth<T> = Partial<
	Omit<ProcessCreateAndUpdateFields<T>, keyof AuthSystemFields>
> & {
	email?: string
	emailVisibility?: boolean
	oldPassword?: string
	password?: string
	passwordConfirm?: string
	verified?: boolean
}

// Update type for Base collections
export type UpdateBase<T> = Partial<
	Omit<ProcessCreateAndUpdateFields<T>, keyof BaseSystemFields>
>

// Get the correct create type for any collection
export type Create<T extends keyof CollectionResponses> =
	CollectionResponses[T] extends AuthSystemFields
		? CreateAuth<CollectionRecords[T]>
		: CreateBase<CollectionRecords[T]>

// Get the correct update type for any collection
export type Update<T extends keyof CollectionResponses> =
	CollectionResponses[T] extends AuthSystemFields
		? UpdateAuth<CollectionRecords[T]>
		: UpdateBase<CollectionRecords[T]>

// Type for usage with type asserted PocketBase instance
// https://github.com/pocketbase/js-sdk#specify-typescript-definitions

export type TypedPocketBase = {
	collection<T extends keyof CollectionResponses>(
		idOrName: T
	): RecordService<CollectionResponses[T]>
} & PocketBase
