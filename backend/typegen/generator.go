package typegen

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"sync"

	"github.com/pocketbase/pocketbase/core"
)

const outputFileName = "pocketbase-types.ts"

type TypeGenerator struct {
	mu            sync.Mutex
	lastTypesHash string
}

func NewTypeGenerator() *TypeGenerator {
	return &TypeGenerator{}
}

func (g *TypeGenerator) Generate(app core.App, config Config) error {
	g.mu.Lock()
	defer g.mu.Unlock()

	outputDir := config.OutputDir
	if outputDir == "" {
		outputDir = app.DataDir()
	}

	if err := os.MkdirAll(outputDir, os.ModePerm); err != nil {
		return fmt.Errorf("failed to create output directory: %w", err)
	}

	content, err := g.buildContent(app)
	if err != nil {
		return fmt.Errorf("failed to build content: %w", err)
	}

	hash := hashContent(content)
	if hash == g.lastTypesHash {
		return nil
	}

	outputPath := filepath.Join(outputDir, outputFileName)
	if err := os.WriteFile(outputPath, []byte(content), 0644); err != nil {
		return fmt.Errorf("failed to write file: %w", err)
	}

	g.lastTypesHash = hash
	return nil
}

func (g *TypeGenerator) buildContent(app core.App) (string, error) {
	collections, err := app.FindAllCollections()
	if err != nil {
		return "", fmt.Errorf("failed to get collections: %w", err)
	}

	sort.Slice(collections, func(i, j int) bool {
		return collections[i].Name < collections[j].Name
	})

	ctx := newCollectionContext(collections)
	w := NewTSWriter()

	g.writeFileHeader(w)
	g.writeImports(w)

	g.writeBrandedTypes(w)
	g.writeBaseInterfaces(w)
	g.writeUtilityTypes(w)

	g.writeCollectionsConst(w, collections)
	g.writeSelectValues(w, collections)

	g.writeRecordTypes(w, app, collections)
	g.writeResponseTypes(w, app, collections)

	g.writeRelationSchemas(w, ctx)

	g.writeCreateTypes(w, collections)
	g.writeUpdateTypes(w, collections)

	g.writeUnionTypes(w, collections)
	g.writeCollectionMaps(w, collections)
	g.writeCollectionRelationMaps(w, collections)

	g.writeExpandUtilityTypes(w)

	g.writeTypeGuards(w, collections)

	g.writeExpandableOptionTypes(w)

	g.writeTypedRecordService(w)
	g.writeTypedPocketBase(w)

	return w.String(), nil
}
