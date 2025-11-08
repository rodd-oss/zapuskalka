import { watch } from "fs";
import { $ } from "bun";

const watcher = watch("backend/migrations", (event, filename) => {
  $`bun run typegen`.then();
});

process.on("SIGINT", () => {
  // close watcher when Ctrl-C is pressed
  console.log("Closing watcher...");
  watcher.close();

  process.exit(0);
});
