"use client";

import { useState, useMemo, type ReactNode } from "react";
import { sortRows, nextSortDir, type SortDir } from "@/lib/sorting";

export interface Column<T> {
  label: string;
  accessor: (row: T) => string;
  hiddenOnMobile?: boolean;
  render?: (row: T, index: number) => ReactNode;
}

interface Props<T> {
  columns: Column<T>[];
  data: T[];
  tableId?: string;
  renderRow?: (row: T, index: number, cells: ReactNode[]) => ReactNode;
}

export function SortableTable<T>({
  columns,
  data,
  tableId,
  renderRow,
}: Props<T>) {
  const [sortCol, setSortCol] = useState<number | null>(null);
  const [sortDir, setSortDir] = useState<SortDir>(null);

  const sorted = useMemo(() => {
    if (sortCol === null || !sortDir) return data;
    return sortRows(data, columns[sortCol].accessor, sortDir);
  }, [data, sortCol, sortDir, columns]);

  function handleSort(colIndex: number) {
    if (sortCol === colIndex) {
      const next = nextSortDir(sortDir);
      setSortDir(next);
      if (next === null) setSortCol(null);
    } else {
      setSortCol(colIndex);
      setSortDir("asc");
    }
  }

  return (
    <table id={tableId}>
      <thead>
        <tr>
          {columns.map((col, i) => (
            <th
              key={i}
              onClick={() => handleSort(i)}
              className={col.hiddenOnMobile ? "hidden-mobile" : undefined}
            >
              {col.label}
              <span style={{ marginLeft: 4, fontSize: 10 }}>
                {sortCol === i && sortDir
                  ? sortDir === "asc"
                    ? " \u25B2"
                    : " \u25BC"
                  : ""}
              </span>
            </th>
          ))}
        </tr>
      </thead>
      <tbody>
        {sorted.map((row, rowIdx) => {
          const cells = columns.map((col, colIdx) => (
            <td
              key={colIdx}
              className={col.hiddenOnMobile ? "hidden-mobile" : undefined}
            >
              {col.render ? col.render(row, rowIdx) : col.accessor(row)}
            </td>
          ));
          return renderRow ? (
            renderRow(row, rowIdx, cells)
          ) : (
            <tr key={rowIdx}>{cells}</tr>
          );
        })}
      </tbody>
    </table>
  );
}
