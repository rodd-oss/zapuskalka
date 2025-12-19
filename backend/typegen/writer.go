package typegen

import (
	"fmt"
	"strings"
)

type TSWriter struct {
	buf    *strings.Builder
	indent int
}

func NewTSWriter() *TSWriter {
	return &TSWriter{
		buf:    &strings.Builder{},
		indent: 0,
	}
}

func (w *TSWriter) String() string {
	return w.buf.String()
}

func (w *TSWriter) Write(s string) {
	w.buf.WriteString(s)
}

func (w *TSWriter) Writef(format string, args ...any) {
	fmt.Fprintf(w.buf, format, args...)
}

func (w *TSWriter) Line(s string) {
	w.writeIndent()
	w.buf.WriteString(s)
	w.buf.WriteString("\n")
}

func (w *TSWriter) Linef(format string, args ...any) {
	w.writeIndent()
	fmt.Fprintf(w.buf, format, args...)
	w.buf.WriteString("\n")
}

func (w *TSWriter) BlankLine() {
	w.buf.WriteString("\n")
}

func (w *TSWriter) writeIndent() {
	for i := 0; i < w.indent; i++ {
		w.buf.WriteString("    ")
	}
}

func (w *TSWriter) Indent() {
	w.indent++
}

func (w *TSWriter) Dedent() {
	if w.indent > 0 {
		w.indent--
	}
}

func (w *TSWriter) ExportType(name, definition string) {
	w.Linef("export type %s = %s;", name, definition)
}

func (w *TSWriter) ExportConst(name, value string) {
	w.Linef("export const %s = %s;", name, value)
}

func (w *TSWriter) ExportConstAs(name, value string) {
	w.Linef("export const %s = %s as const;", name, value)
}

func (w *TSWriter) BeginExportInterface(name, generics, extends string) {
	w.writeIndent()
	w.buf.WriteString("export interface ")
	w.buf.WriteString(name)
	if generics != "" {
		w.buf.WriteString(generics)
	}
	if extends != "" {
		w.buf.WriteString(" extends ")
		w.buf.WriteString(extends)
	}
	w.buf.WriteString(" {\n")
	w.indent++
}

func (w *TSWriter) BeginExportType(name string) {
	w.Linef("export type %s = {", name)
	w.indent++
}

func (w *TSWriter) BeginType(name string) {
	w.Linef("type %s = {", name)
	w.indent++
}

func (w *TSWriter) EndBlock() {
	w.indent--
	w.Line("}")
}

func (w *TSWriter) EndBlockSemi() {
	w.indent--
	w.Line("};")
}

func (w *TSWriter) EndBlockAsConst() {
	w.indent--
	w.Line("} as const;")
}

func (w *TSWriter) Field(name, typ string, optional bool) {
	if optional {
		w.Linef("%s?: %s;", name, typ)
	} else {
		w.Linef("%s: %s;", name, typ)
	}
}

func (w *TSWriter) FieldRequired(name, typ string) {
	w.Linef("%s: %s;", name, typ)
}

func (w *TSWriter) FieldOptional(name, typ string) {
	w.Linef("%s?: %s;", name, typ)
}

func (w *TSWriter) FieldQuoted(name, typ string, optional bool) {
	if optional {
		w.Linef("\"%s\"?: %s;", name, typ)
	} else {
		w.Linef("\"%s\": %s;", name, typ)
	}
}

func (w *TSWriter) BeginExportFunction(signature string) {
	w.Linef("export function %s {", signature)
	w.indent++
}

func (w *TSWriter) EndFunction() {
	w.indent--
	w.Line("}")
}

func (w *TSWriter) Raw(s string) {
	w.buf.WriteString(s)
}

func (w *TSWriter) RawLine(s string) {
	w.buf.WriteString(s)
	w.buf.WriteString("\n")
}
