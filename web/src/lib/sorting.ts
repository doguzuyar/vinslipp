export type SortDir = "asc" | "desc" | null;

export function nextSortDir(current: SortDir): SortDir {
  if (!current) return "asc";
  if (current === "asc") return "desc";
  return null;
}

export function sortRows<T>(
  rows: T[],
  colAccessor: (row: T) => string,
  dir: SortDir
): T[] {
  if (!dir) return rows;
  const sorted = [...rows].sort((a, b) => {
    const aText = colAccessor(a).trim();
    const bText = colAccessor(b).trim();
    if (aText === "\u2014" && bText === "\u2014") return 0;
    if (aText === "\u2014") return 1;
    if (bText === "\u2014") return -1;
    const aNum = parseFloat(aText.replace(/[^0-9.-]/g, ""));
    const bNum = parseFloat(bText.replace(/[^0-9.-]/g, ""));
    let result: number;
    if (!isNaN(aNum) && !isNaN(bNum)) {
      result = aNum - bNum;
    } else {
      result = aText.localeCompare(bText);
    }
    return dir === "asc" ? result : -result;
  });
  return sorted;
}
