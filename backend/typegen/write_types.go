package typegen

import (
	"fmt"
	"log/slog"
	"sort"
	"strings"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/dbutils"
)

func (g *TypeGenerator) writeFileHeader(w *TSWriter) {
	w.RawLine("/**")
	w.RawLine(" * PocketBase TypeScript Types")
	w.RawLine(" * Auto-generated - DO NOT EDIT")
	w.RawLine(" */")
	w.BlankLine()
}

func (g *TypeGenerator) writeImports(w *TSWriter) {
	w.RawLine("import PocketBase, {")
	w.Indent()
	w.Line("RecordService,")
	w.Line("type ListResult,")
	w.Line("type RecordSubscription,")
	w.Line("type UnsubscribeFunc,")
	w.Line("type RecordOptions,")
	w.Line("type RecordListOptions,")
	w.Line("type RecordFullListOptions,")
	w.Line("type RecordSubscribeOptions,")
	w.Dedent()
	w.RawLine("} from 'pocketbase';")
	w.BlankLine()
}

func (g *TypeGenerator) writeBrandedTypes(w *TSWriter) {
	w.ExportType("RecordIdString", "string & { readonly __recordId: unique symbol }")
	w.ExportType("AutodateString", "string & { readonly __autodate: unique symbol }")
	w.ExportType("HTMLString", "string & { readonly __html: unique symbol }")
	w.ExportType("Email", "string & { readonly __email: unique symbol }")
	w.ExportType("URL", "string & { readonly __url: unique symbol }")
	w.BlankLine()

	w.BeginExportInterface("GeoPoint", "", "")
	w.FieldRequired("lat", "number")
	w.FieldRequired("lon", "number")
	w.EndBlockSemi()
	w.BlankLine()
}

func (g *TypeGenerator) writeBaseInterfaces(w *TSWriter) {
	w.BeginExportInterface("BaseSystemFields", "", "")
	w.FieldRequired("id", "RecordIdString")
	w.FieldRequired("created", "AutodateString")
	w.FieldRequired("updated", "AutodateString")
	w.EndBlockSemi()
	w.BlankLine()

	w.BeginExportInterface("AuthSystemFields", "", "")
	w.FieldRequired("email", "Email")
	w.FieldRequired("emailVisibility", "boolean")
	w.FieldRequired("verified", "boolean")
	w.EndBlockSemi()
	w.BlankLine()
}

func (g *TypeGenerator) writeUtilityTypes(w *TSWriter) {
	w.ExportType("SystemFields", "keyof BaseSystemFields | 'collectionId' | 'collectionName' | 'expand'")
	w.BlankLine()
	w.ExportType("RecordCreate<T>", "Omit<T, SystemFields> & { id?: string }")
	w.ExportType("RecordUpdate<T>", "Partial<Omit<T, SystemFields>>")
	w.BlankLine()
}

func (g *TypeGenerator) writeCollectionsConst(w *TSWriter, collections []*core.Collection) {
	if len(collections) == 0 {
		return
	}

	w.Line("export const Collections = {")
	w.Indent()
	for _, coll := range collections {
		w.Linef("%s: \"%s\",", pascalCase(coll.Name), coll.Name)
	}
	w.EndBlockAsConst()
	w.BlankLine()

	w.ExportType("Collections", "typeof Collections[keyof typeof Collections]")
	w.BlankLine()
}

func (g *TypeGenerator) writeSelectValues(w *TSWriter, collections []*core.Collection) {
	hasAny := false
	for _, coll := range collections {
		for _, field := range coll.Fields {
			selectField, ok := field.(*core.SelectField)
			if !ok || len(selectField.Values) == 0 {
				continue
			}

			if !hasAny {
				hasAny = true
			}

			baseName := pascalCase(coll.Name) + pascalCase(field.GetName())

			var values strings.Builder
			for i, v := range selectField.Values {
				if i > 0 {
					values.WriteString(", ")
				}
				values.WriteString("\"" + escapeTypeScriptString(v) + "\"")
			}

			w.ExportConstAs(baseName+"Values", "["+values.String()+"]")
			w.ExportType(baseName+"Options", "typeof "+baseName+"Values[number]")
			w.BlankLine()
		}
	}
}

func (g *TypeGenerator) writeRecordTypes(w *TSWriter, app core.App, collections []*core.Collection) {
	if len(collections) == 0 {
		return
	}

	for _, coll := range collections {
		if err := g.writeRecordType(w, coll); err != nil {
			app.Logger().Warn(
				"Failed to generate record type for collection",
				slog.String("collection", coll.Name),
				slog.String("error", err.Error()),
			)
		}
	}
}

func (g *TypeGenerator) writeRecordType(w *TSWriter, coll *core.Collection) error {
	baseName := pascalCase(coll.Name)
	interfaceName := baseName + "Record"

	jsonFields := g.getJSONFieldNames(coll)
	genericParams := g.buildGenericParams(jsonFields)

	w.BeginExportInterface(interfaceName, genericParams, "")

	for _, field := range coll.Fields {
		name, typ, optional, skip := g.buildFieldInfo(field, jsonFields, coll.Name, coll.IsAuth())
		if skip {
			continue
		}
		w.Field(name, typ, optional)
	}

	w.EndBlockSemi()
	w.BlankLine()

	return nil
}

func (g *TypeGenerator) writeResponseTypes(w *TSWriter, app core.App, collections []*core.Collection) {
	if len(collections) == 0 {
		return
	}

	for _, coll := range collections {
		if err := g.writeResponseType(w, coll); err != nil {
			app.Logger().Warn(
				"Failed to generate response type for collection",
				slog.String("collection", coll.Name),
				slog.String("error", err.Error()),
			)
		}
	}
}

func (g *TypeGenerator) writeResponseType(w *TSWriter, coll *core.Collection) error {
	baseName := pascalCase(coll.Name)
	responseName := baseName + "Response"
	recordName := baseName + "Record"

	jsonFields := g.getJSONFieldNames(coll)
	responseGenericParams := g.buildResponseGenericParams(jsonFields)
	genericArgs := g.buildGenericArgs(jsonFields)

	extendsClause := recordName + genericArgs + ", BaseSystemFields"
	if coll.IsAuth() {
		extendsClause += ", AuthSystemFields"
	}

	w.BeginExportInterface(responseName, responseGenericParams, extendsClause)
	w.FieldRequired("collectionId", "string")
	w.Linef("collectionName: \"%s\";", coll.Name)
	w.FieldOptional("expand", "Expand")
	w.EndBlockSemi()
	w.BlankLine()

	return nil
}

func (g *TypeGenerator) buildFieldInfo(field core.Field, jsonFields []string, collectionName string, isAuth bool) (name, typ string, optional, skip bool) {
	fieldName := field.GetName()

	if fieldName == "id" || fieldName == "created" || fieldName == "updated" ||
		fieldName == "collectionId" || fieldName == "collectionName" {
		return "", "", false, true
	}

	if isAuth {
		if fieldName == "email" || fieldName == "emailVisibility" ||
			fieldName == "verified" || fieldName == "tokenKey" {
			return "", "", false, true
		}
	}

	if field.Type() == core.FieldTypePassword {
		return "", "", false, true
	}

	name = fieldName
	optional = !g.isFieldRequired(field)

	if field.Type() == core.FieldTypeJSON && containsString(jsonFields, fieldName) {
		typ = pascalCase(fieldName)
	} else {
		typ = g.fieldTypeToTS(field, collectionName)
	}

	return name, typ, optional, false
}

func (g *TypeGenerator) isFieldRequired(field core.Field) bool {
	if field.Type() == core.FieldTypeAutodate {
		return false
	}

	switch f := field.(type) {
	case *core.TextField:
		return f.Required
	case *core.NumberField:
		return f.Required
	case *core.BoolField:
		return f.Required
	case *core.EmailField:
		return f.Required
	case *core.URLField:
		return f.Required
	case *core.DateField:
		return f.Required
	case *core.SelectField:
		return f.Required
	case *core.JSONField:
		return f.Required
	case *core.FileField:
		return f.Required
	case *core.RelationField:
		return f.Required
	case *core.EditorField:
		return f.Required
	case *core.GeoPointField:
		return f.Required
	default:
		return false
	}
}

func (g *TypeGenerator) fieldTypeToTS(field core.Field, collectionName string) string {
	fieldType := field.Type()

	switch fieldType {
	case core.FieldTypeText, core.FieldTypePassword:
		return "string"

	case core.FieldTypeEditor:
		return "HTMLString"

	case core.FieldTypeEmail:
		return "Email"

	case core.FieldTypeURL:
		return "URL"

	case core.FieldTypeDate:
		return "string"

	case core.FieldTypeAutodate:
		return "AutodateString"

	case core.FieldTypeSelect:
		if selectField, ok := field.(*core.SelectField); ok {
			if len(selectField.Values) > 0 {
				typeName := pascalCase(collectionName) + pascalCase(field.GetName()) + "Options"
				if selectField.MaxSelect > 1 {
					return typeName + "[]"
				}
				return typeName
			}
			if selectField.MaxSelect > 1 {
				return "string[]"
			}
		}
		return "string"

	case core.FieldTypeNumber:
		return "number"

	case core.FieldTypeBool:
		if boolField, ok := field.(*core.BoolField); ok && boolField.Required {
			return "true"
		}
		return "boolean"

	case core.FieldTypeJSON:
		return "any"

	case core.FieldTypeRelation:
		if relField, ok := field.(*core.RelationField); ok {
			if relField.MaxSelect > 1 {
				return "RecordIdString[]"
			}
		}
		return "RecordIdString"

	case core.FieldTypeFile:
		if fileField, ok := field.(*core.FileField); ok {
			if fileField.MaxSelect > 1 {
				return "string[]"
			}
		}
		return "string"

	case core.FieldTypeGeoPoint:
		return "GeoPoint"

	default:
		return "any"
	}
}

func (g *TypeGenerator) getJSONFieldNames(coll *core.Collection) []string {
	var names []string
	for _, field := range coll.Fields {
		if field.Type() == core.FieldTypeJSON {
			names = append(names, field.GetName())
		}
	}
	return names
}

func (g *TypeGenerator) buildGenericParams(jsonFields []string) string {
	if len(jsonFields) == 0 {
		return ""
	}

	params := make([]string, len(jsonFields))
	for i, name := range jsonFields {
		params[i] = fmt.Sprintf("%s = unknown", pascalCase(name))
	}
	return "<" + strings.Join(params, ", ") + ">"
}

func (g *TypeGenerator) buildResponseGenericParams(jsonFields []string) string {
	params := make([]string, 0, len(jsonFields)+1)
	for _, name := range jsonFields {
		params = append(params, fmt.Sprintf("%s = unknown", pascalCase(name)))
	}
	params = append(params, "Expand = {}")
	return "<" + strings.Join(params, ", ") + ">"
}

func (g *TypeGenerator) buildGenericArgs(jsonFields []string) string {
	if len(jsonFields) == 0 {
		return ""
	}

	args := make([]string, len(jsonFields))
	for i, name := range jsonFields {
		args[i] = pascalCase(name)
	}
	return "<" + strings.Join(args, ", ") + ">"
}

type backRelationInfo struct {
	SourceCollectionName string
	SourceFieldName      string
	IsMulti              bool
}

type collectionContext struct {
	collections      []*core.Collection
	collectionMap    map[string]string
	backRelationsMap map[string][]backRelationInfo
}

func newCollectionContext(collections []*core.Collection) *collectionContext {
	ctx := &collectionContext{
		collections:   collections,
		collectionMap: make(map[string]string),
	}

	for _, c := range collections {
		ctx.collectionMap[c.Id] = c.Name
	}

	ctx.backRelationsMap = buildBackRelationsMapInternal(collections)

	return ctx
}

func buildBackRelationsMapInternal(collections []*core.Collection) map[string][]backRelationInfo {
	result := make(map[string][]backRelationInfo)

	for _, coll := range collections {
		for _, field := range coll.Fields {
			relField, ok := field.(*core.RelationField)
			if !ok {
				continue
			}

			_, hasUniqueIndex := dbutils.FindSingleColumnUniqueIndex(coll.Indexes, relField.Name)

			info := backRelationInfo{
				SourceCollectionName: coll.Name,
				SourceFieldName:      relField.Name,
				IsMulti:              !hasUniqueIndex,
			}

			result[relField.CollectionId] = append(result[relField.CollectionId], info)
		}
	}

	return result
}

func (g *TypeGenerator) writeRelationSchemas(w *TSWriter, ctx *collectionContext) {
	for _, coll := range ctx.collections {
		g.writeForwardRelations(w, coll, ctx.collectionMap)
		g.writeBackRelations(w, coll, ctx.backRelationsMap)
	}
}

func (g *TypeGenerator) writeForwardRelations(w *TSWriter, coll *core.Collection, collectionMap map[string]string) {
	baseName := pascalCase(coll.Name)
	relationsTypeName := baseName + "Relations"

	relationCount := 0
	for _, field := range coll.Fields {
		if _, ok := field.(*core.RelationField); ok {
			relationCount++
		}
	}

	type relationEntry struct {
		fieldName   string
		relTypeName string
		isMulti     bool
		relCollName string
	}

	relations := make([]relationEntry, 0, relationCount)

	for _, field := range coll.Fields {
		relField, ok := field.(*core.RelationField)
		if !ok {
			continue
		}

		relCollName, exists := collectionMap[relField.CollectionId]
		if !exists {
			continue
		}

		relations = append(relations, relationEntry{
			fieldName:   field.GetName(),
			relTypeName: pascalCase(relCollName) + "Response",
			isMulti:     relField.MaxSelect > 1,
			relCollName: relCollName,
		})
	}

	if len(relations) == 0 {
		w.ExportType(relationsTypeName, "{}")
		w.BlankLine()
	} else {
		w.BeginExportType(relationsTypeName)
		for _, rel := range relations {
			w.Linef("%s: { response: %s; isMulti: %t; collection: \"%s\" };",
				rel.fieldName, rel.relTypeName, rel.isMulti, rel.relCollName)
		}
		w.EndBlockSemi()
		w.BlankLine()
	}
}

func (g *TypeGenerator) writeBackRelations(w *TSWriter, coll *core.Collection, backRelationsMap map[string][]backRelationInfo) {
	baseName := pascalCase(coll.Name)
	backRelationsTypeName := baseName + "BackRelations"
	backRels := backRelationsMap[coll.Id]

	sort.Slice(backRels, func(i, j int) bool {
		keyI := backRels[i].SourceCollectionName + "_via_" + backRels[i].SourceFieldName
		keyJ := backRels[j].SourceCollectionName + "_via_" + backRels[j].SourceFieldName
		return keyI < keyJ
	})

	if len(backRels) == 0 {
		w.ExportType(backRelationsTypeName, "{}")
		w.BlankLine()
	} else {
		w.BeginExportType(backRelationsTypeName)
		for _, backRel := range backRels {
			key := backRel.SourceCollectionName + "_via_" + backRel.SourceFieldName
			relTypeName := pascalCase(backRel.SourceCollectionName) + "Response"
			w.Linef("\"%s\": { response: %s; isMulti: %t; collection: \"%s\" };",
				key, relTypeName, backRel.IsMulti, backRel.SourceCollectionName)
		}
		w.EndBlockSemi()
		w.BlankLine()
	}
}

func (g *TypeGenerator) writeCreateTypes(w *TSWriter, collections []*core.Collection) {
	for _, coll := range collections {
		if coll.IsView() {
			continue
		}

		baseName := pascalCase(coll.Name)
		recordName := baseName + "Record"
		createName := baseName + "Create"

		if coll.IsAuth() {
			w.Linef("export type %s = %s & {", createName, recordName)
			w.Indent()
			w.FieldOptional("id", "string")
			w.FieldRequired("email", "string")
			w.FieldRequired("password", "string")
			w.FieldOptional("passwordConfirm", "string")
			w.EndBlockSemi()
			w.BlankLine()
		} else {
			w.ExportType(createName, recordName+" & { id?: string }")
			w.BlankLine()
		}
	}
}

func (g *TypeGenerator) writeUpdateTypes(w *TSWriter, collections []*core.Collection) {
	for _, coll := range collections {
		if coll.IsView() {
			continue
		}

		baseName := pascalCase(coll.Name)
		recordName := baseName + "Record"
		updateName := baseName + "Update"

		if coll.IsAuth() {
			w.Linef("export type %s = Partial<%s> & {", updateName, recordName)
			w.Indent()
			w.FieldOptional("email", "string")
			w.FieldOptional("password", "string")
			w.FieldOptional("passwordConfirm", "string")
			w.FieldOptional("oldPassword", "string")
			w.EndBlockSemi()
			w.BlankLine()
		} else {
			w.ExportType(updateName, fmt.Sprintf("Partial<%s>", recordName))
			w.BlankLine()
		}
	}
}

func (g *TypeGenerator) writeUnionTypes(w *TSWriter, collections []*core.Collection) {
	if len(collections) == 0 {
		return
	}

	w.Write("export type AllResponses = ")
	for i, coll := range collections {
		if i > 0 {
			w.Write(" | ")
		}
		w.Writef("%sResponse", pascalCase(coll.Name))
	}
	w.Write(";\n\n")

	w.Write("export type CollectionNames = ")
	for i, coll := range collections {
		if i > 0 {
			w.Write(" | ")
		}
		w.Writef("\"%s\"", coll.Name)
	}
	w.Write(";\n\n")
}

func (g *TypeGenerator) writeCollectionMaps(w *TSWriter, collections []*core.Collection) {
	var nonViewCollections []*core.Collection
	for _, coll := range collections {
		if !coll.IsView() {
			nonViewCollections = append(nonViewCollections, coll)
		}
	}

	w.BeginExportType("CollectionRecords")
	for _, coll := range collections {
		w.Linef("\"%s\": %sRecord;", coll.Name, pascalCase(coll.Name))
	}
	w.EndBlockSemi()
	w.BlankLine()

	w.BeginExportType("CollectionResponses")
	for _, coll := range collections {
		w.Linef("\"%s\": %sResponse;", coll.Name, pascalCase(coll.Name))
	}
	w.EndBlockSemi()
	w.BlankLine()

	w.BeginExportType("CollectionCreates")
	for _, coll := range nonViewCollections {
		w.Linef("\"%s\": %sCreate;", coll.Name, pascalCase(coll.Name))
	}
	w.EndBlockSemi()
	w.BlankLine()

	w.BeginExportType("CollectionUpdates")
	for _, coll := range nonViewCollections {
		w.Linef("\"%s\": %sUpdate;", coll.Name, pascalCase(coll.Name))
	}
	w.EndBlockSemi()
	w.BlankLine()
}

func (g *TypeGenerator) writeCollectionRelationMaps(w *TSWriter, collections []*core.Collection) {
	w.BeginExportType("CollectionRelations")
	for _, coll := range collections {
		w.Linef("\"%s\": %sRelations;", coll.Name, pascalCase(coll.Name))
	}
	w.EndBlockSemi()
	w.BlankLine()

	w.BeginExportType("CollectionBackRelations")
	for _, coll := range collections {
		w.Linef("\"%s\": %sBackRelations;", coll.Name, pascalCase(coll.Name))
	}
	w.EndBlockSemi()
	w.BlankLine()
}

func (g *TypeGenerator) writeExpandUtilityTypes(w *TSWriter) {
	g.writeSplitType(w)
	g.writeTrimTypes(w)
	g.writeSplitPathType(w)
	g.writeGetFirstPathSegmentType(w)
	g.writeGetRelationInfoType(w)
	g.writeResolveSimpleExpandFieldType(w)
	g.writeWithNestedExpandType(w)
	g.writeResolveNestedExpandType(w)
	g.writeResolveExpandFieldType(w)
	g.writeBuildExpandFromListType(w)
	g.writeInferExpandType(w)
}

func (g *TypeGenerator) writeSplitType(w *TSWriter) {
	w.Line("type Split<S extends string, D extends string = \",\"> = ")
	w.Indent()
	w.Line("string extends S ? string[] :")
	w.Line("S extends \"\" ? [] :")
	w.Line("S extends `${infer T}${D}${infer U}` ? [T, ...Split<U, D>] : [S];")
	w.Dedent()
	w.BlankLine()
}

func (g *TypeGenerator) writeTrimTypes(w *TSWriter) {
	w.Line("type TrimLeft<S extends string> = S extends ` ${infer R}` ? TrimLeft<R> : S;")
	w.Line("type TrimRight<S extends string> = S extends `${infer L} ` ? TrimRight<L> : S;")
	w.Line("type Trim<S extends string> = TrimLeft<TrimRight<S>>;")
	w.BlankLine()
}

func (g *TypeGenerator) writeSplitPathType(w *TSWriter) {
	w.Line("type SplitPath<S extends string> = ")
	w.Indent()
	w.Line("S extends `${infer Head}.${infer Tail}` ? [Head, ...SplitPath<Tail>] : [S];")
	w.Dedent()
	w.BlankLine()
}

func (g *TypeGenerator) writeGetFirstPathSegmentType(w *TSWriter) {
	w.Line("type GetFirstPathSegment<S extends string> = ")
	w.Indent()
	w.Line("S extends `${infer Head}.${infer _Tail}` ? Head : S;")
	w.Dedent()
	w.BlankLine()
}

func (g *TypeGenerator) writeGetRelationInfoType(w *TSWriter) {
	w.Line("type GetRelationInfo<C extends Collections, F extends string> = ")
	w.Indent()
	w.Line("Trim<F> extends keyof CollectionRelations[C] ")
	w.Indent()
	w.Line("? CollectionRelations[C][Trim<F>]")
	w.Line(": Trim<F> extends keyof CollectionBackRelations[C]")
	w.Indent()
	w.Line("? CollectionBackRelations[C][Trim<F>]")
	w.Line(": { response: unknown; isMulti: false; collection: never };")
	w.Dedent()
	w.Dedent()
	w.Dedent()
	w.BlankLine()
}

func (g *TypeGenerator) writeResolveSimpleExpandFieldType(w *TSWriter) {
	w.Line("type ResolveSimpleExpandField<C extends Collections, F extends string> = ")
	w.Indent()
	w.Line("GetRelationInfo<C, F> extends { response: infer R; isMulti: infer M }")
	w.Indent()
	w.Line("? M extends true ? R[] : R")
	w.Line(": unknown;")
	w.Dedent()
	w.Dedent()
	w.BlankLine()
}

func (g *TypeGenerator) writeWithNestedExpandType(w *TSWriter) {
	w.Line("type WithNestedExpand<T, NestedExpand> = ")
	w.Indent()
	w.Line("T extends object ")
	w.Indent()
	w.Line("? Omit<T, 'expand'> & { expand?: NestedExpand }")
	w.Line(": T;")
	w.Dedent()
	w.Dedent()
	w.BlankLine()
}

func (g *TypeGenerator) writeResolveNestedExpandType(w *TSWriter) {
	w.Line("type ResolveNestedExpand<C extends Collections, Path extends string[]> =")
	w.Indent()
	w.Line("Path extends [infer First extends string, ...infer Rest extends string[]]")
	w.Indent()
	w.Line("? GetRelationInfo<C, First> extends { response: infer R; isMulti: infer M; collection: infer NC }")
	w.Indent()
	w.Line("? Rest extends []")
	w.Indent()
	w.Line("? M extends true ? R[] : R")
	w.Line(": NC extends Collections")
	w.Indent()
	w.Line("? M extends true")
	w.Indent()
	w.Line("? WithNestedExpand<R, ResolveNestedExpand<NC, Rest>>[]")
	w.Line(": WithNestedExpand<R, ResolveNestedExpand<NC, Rest>>")
	w.Dedent()
	w.Line(": unknown")
	w.Dedent()
	w.Dedent()
	w.Line(": unknown")
	w.Dedent()
	w.Line(": {};")
	w.Dedent()
	w.Dedent()
	w.BlankLine()
}

func (g *TypeGenerator) writeResolveExpandFieldType(w *TSWriter) {
	w.Line("type ResolveExpandField<C extends Collections, F extends string> = ")
	w.Indent()
	w.Line("F extends `${infer _Head}.${infer _Tail}`")
	w.Indent()
	w.Line("? ResolveNestedExpand<C, SplitPath<Trim<F>>>")
	w.Line(": ResolveSimpleExpandField<C, F>;")
	w.Dedent()
	w.Dedent()
	w.BlankLine()
}

func (g *TypeGenerator) writeBuildExpandFromListType(w *TSWriter) {
	w.Line("type BuildExpandFromList<C extends Collections, L extends string[]> = ")
	w.Indent()
	w.Line("L extends [] ? {} :")
	w.Line("L extends [infer First extends string, ...infer Rest extends string[]] ")
	w.Indent()
	w.Line("? { [K in Trim<GetFirstPathSegment<First>>]?: ResolveExpandField<C, First> } & BuildExpandFromList<C, Rest>")
	w.Line(": {};")
	w.Dedent()
	w.Dedent()
	w.BlankLine()
}

func (g *TypeGenerator) writeInferExpandType(w *TSWriter) {
	w.Line("type InferExpand<C extends Collections, E extends string> = ")
	w.Indent()
	w.Line("E extends \"\" ? {} : ")
	w.Line("BuildExpandFromList<C, Split<E, \",\">>;")
	w.Dedent()
	w.BlankLine()
}

func (g *TypeGenerator) writeTypeGuards(w *TSWriter, collections []*core.Collection) {
	for _, coll := range collections {
		funcName := "is" + pascalCase(coll.Name) + "Response"
		typeName := pascalCase(coll.Name) + "Response"

		w.BeginExportFunction(funcName + "(record: AllResponses): record is " + typeName)
		w.Linef("return record.collectionName === \"%s\";", coll.Name)
		w.EndFunction()
		w.BlankLine()
	}
}

func (g *TypeGenerator) writeExpandableOptionTypes(w *TSWriter) {
	w.ExportType("RecordOptionsWithExpand<E extends string = \"\">",
		"Omit<RecordOptions, 'expand'> & { expand?: E }")
	w.ExportType("RecordListOptionsWithExpand<E extends string = \"\">",
		"Omit<RecordListOptions, 'expand'> & { expand?: E }")
	w.ExportType("RecordFullListOptionsWithExpand<E extends string = \"\">",
		"Omit<RecordFullListOptions, 'expand'> & { expand?: E }")
	w.ExportType("RecordSubscribeOptionsWithExpand<E extends string = \"\">",
		"Omit<RecordSubscribeOptions, 'expand'> & { expand?: E }")
	w.BlankLine()
}

func (g *TypeGenerator) writeTypedRecordService(w *TSWriter) {
	w.ExportType("WithExpand<T, E>", "Omit<T, 'expand'> & { expand?: E }")
	w.BlankLine()

	w.BeginExportInterface("TypedRecordService<C extends Collections>", "", "")

	w.Line("getOne<E extends string = \"\">(")
	w.Indent()
	w.Line("id: string,")
	w.Line("options?: RecordOptionsWithExpand<E>")
	w.Dedent()
	w.Line("): Promise<WithExpand<CollectionResponses[C], InferExpand<C, E>>>;")
	w.BlankLine()

	w.Line("getList<E extends string = \"\">(")
	w.Indent()
	w.Line("page?: number,")
	w.Line("perPage?: number,")
	w.Line("options?: RecordListOptionsWithExpand<E>")
	w.Dedent()
	w.Line("): Promise<ListResult<WithExpand<CollectionResponses[C], InferExpand<C, E>>>>;")
	w.BlankLine()

	w.Line("getFirstListItem<E extends string = \"\">(")
	w.Indent()
	w.Line("filter: string,")
	w.Line("options?: RecordListOptionsWithExpand<E>")
	w.Dedent()
	w.Line("): Promise<WithExpand<CollectionResponses[C], InferExpand<C, E>>>;")
	w.BlankLine()

	w.Line("getFullList<E extends string = \"\">(")
	w.Indent()
	w.Line("options?: RecordFullListOptionsWithExpand<E>")
	w.Dedent()
	w.Line("): Promise<WithExpand<CollectionResponses[C], InferExpand<C, E>>[]>;")
	w.BlankLine()

	w.Line("create<E extends string = \"\">(")
	w.Indent()
	w.Line("bodyOrRecord: C extends keyof CollectionCreates ? CollectionCreates[C] | FormData : FormData,")
	w.Line("options?: RecordOptionsWithExpand<E>")
	w.Dedent()
	w.Line("): Promise<WithExpand<CollectionResponses[C], InferExpand<C, E>>>;")
	w.BlankLine()

	w.Line("update<E extends string = \"\">(")
	w.Indent()
	w.Line("id: string,")
	w.Line("bodyOrRecord: C extends keyof CollectionUpdates ? CollectionUpdates[C] | FormData : FormData,")
	w.Line("options?: RecordOptionsWithExpand<E>")
	w.Dedent()
	w.Line("): Promise<WithExpand<CollectionResponses[C], InferExpand<C, E>>>;")
	w.BlankLine()

	w.Line("subscribe<E extends string = \"\">(")
	w.Indent()
	w.Line("topic: string,")
	w.Line("callback: (data: RecordSubscription<WithExpand<CollectionResponses[C], InferExpand<C, E>>>) => void,")
	w.Line("options?: RecordSubscribeOptionsWithExpand<E>")
	w.Dedent()
	w.Line("): Promise<UnsubscribeFunc>;")

	w.EndBlockSemi()
	w.BlankLine()
}

func (g *TypeGenerator) writeTypedPocketBase(w *TSWriter) {
	w.BeginExportInterface("TypedPocketBase", "", "PocketBase")
	w.Line("collection<C extends Collections>(idOrName: C): TypedRecordService<C> & RecordService<CollectionResponses[C]>;")
	w.Line("collection(idOrName: string): RecordService;")
	w.EndBlockSemi()
}
