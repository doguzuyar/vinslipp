import fs from "fs";
import path from "path";
import type { ReleaseData, Metadata } from "@/types";

const DATA_DIR = path.join(process.cwd(), "..", "data");

export function getReleaseData(): ReleaseData {
  return JSON.parse(fs.readFileSync(path.join(DATA_DIR, "releases.json"), "utf-8"));
}

export function getMetadata(): Metadata {
  return JSON.parse(fs.readFileSync(path.join(DATA_DIR, "metadata.json"), "utf-8"));
}
