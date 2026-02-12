"use client";

import { useState, useMemo } from "react";
import type { HistoryWine } from "@/types";
import type { AuthUser } from "@/lib/firebase";
import { SortableTable, type Column } from "@/components/SortableTable";
import { useRowPopup, RowPopup } from "@/components/RowPopup";
import { BlogModal, type BlogWine } from "@/components/blog/BlogModal";

interface Props {
  wines: HistoryWine[];
  selectedLocation: string;
  user: AuthUser | null;
}

export function HistoryTab({ wines, selectedLocation, user }: Props) {
  const { expandedId, popupPos, popupRef, scrollRef, handleRowClick } = useRowPopup();
  const [blogWine, setBlogWine] = useState<BlogWine | null>(null);

  const columns: Column<HistoryWine>[] = useMemo(
    () => [
      {
        label: "Winery",
        accessor: (w) => w.winery,
      },
      {
        label: "Wine name",
        accessor: (w) => w.wineName,
      },
      {
        label: "Vintage",
        accessor: (w) => w.vintage,
      },
      {
        label: "Region",
        accessor: (w) => w.region,
        hiddenOnMobile: true,
      },
      {
        label: "Style",
        accessor: (w) => w.style,
      },
    ],
    []
  );

  const expandedWineData = expandedId ? wines.find((w) => w.link === expandedId) : null;

  return (
    <div className="tab-scroll" ref={scrollRef} style={{ position: "relative" }}>
      <SortableTable
        columns={columns}
        data={wines}
        tableId="history-table"
        renderRow={(wine, idx, cells) => (
          <tr
            key={idx}
            className="clickable"
            style={{ backgroundColor: "var(--bg-alt)" }}
            onClick={(e) => handleRowClick(wine.link, e)}
          >
            {cells}
          </tr>
        )}
      />
      {expandedWineData && popupPos && (
        <RowPopup
          popupRef={popupRef}
          popupPos={popupPos}
          links={[
            { label: "Vivino", href: expandedWineData.link },
            { label: "Blog", onClick: () => setBlogWine({ id: `${expandedWineData.winery}-${expandedWineData.wineName}-${expandedWineData.vintage}`, name: expandedWineData.wineName, winery: expandedWineData.winery, vintage: expandedWineData.vintage }) },
          ]}
        />
      )}
      <p style={{ fontWeight: 500, marginTop: 16, fontSize: 14, color: "var(--text-muted)" }}>
        {wines.length} wines{selectedLocation ? ` consumed at ${selectedLocation}` : ""}
      </p>
      {blogWine && <BlogModal wine={blogWine} user={user} onClose={() => setBlogWine(null)} />}
    </div>
  );
}
