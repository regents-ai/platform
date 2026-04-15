import assert from "node:assert/strict";
import { describe, it } from "node:test";

import {
  findNearestScrollContainer,
  groupCardRectsIntoRows,
  selectCenteredRowWindow,
  type GalleryCardRect,
  type GalleryRow,
} from "./formation_pass_gallery.ts";

function buildRows({
  rowCount,
  cardsPerRow,
  rowHeight = 220,
  rowGap = 32,
}: {
  rowCount: number;
  cardsPerRow: number;
  rowHeight?: number;
  rowGap?: number;
}): GalleryRow[] {
  const rects: GalleryCardRect[] = [];

  for (let rowIndex = 0; rowIndex < rowCount; rowIndex += 1) {
    const top = rowIndex * (rowHeight + rowGap);
    const bottom = top + rowHeight;

    for (let cardIndex = 0; cardIndex < cardsPerRow; cardIndex += 1) {
      rects.push({ top, bottom });
    }
  }

  return groupCardRectsIntoRows(rects);
}

function sortedIndices(indices: Set<number>): number[] {
  return Array.from(indices).sort((left, right) => left - right);
}

describe("formation pass gallery helpers", () => {
  it("groups two-column cards into whole rows", () => {
    const rows = buildRows({ rowCount: 4, cardsPerRow: 2 });

    assert.equal(rows.length, 4);
    assert.deepEqual(rows.map((row) => row.indices), [
      [0, 1],
      [2, 3],
      [4, 5],
      [6, 7],
    ]);
  });

  it("groups three-column cards into whole rows", () => {
    const rows = buildRows({ rowCount: 3, cardsPerRow: 3 });

    assert.equal(rows.length, 3);
    assert.deepEqual(rows.map((row) => row.indices), [
      [0, 1, 2],
      [3, 4, 5],
      [6, 7, 8],
    ]);
  });

  it("keeps all cards active when the gallery is smaller than the target window", () => {
    const rows = buildRows({ rowCount: 3, cardsPerRow: 3 });
    const active = selectCenteredRowWindow(rows, rows[1]!.center, 12);

    assert.deepEqual(sortedIndices(active), [0, 1, 2, 3, 4, 5, 6, 7, 8]);
  });

  it("activates the first whole rows when the viewport is near the top", () => {
    const rows = buildRows({ rowCount: 8, cardsPerRow: 3 });
    const active = selectCenteredRowWindow(rows, rows[0]!.center, 12);

    assert.deepEqual(sortedIndices(active), [
      0, 1, 2,
      3, 4, 5,
      6, 7, 8,
      9, 10, 11,
    ]);
  });

  it("activates rows around the viewport center in the middle of the list", () => {
    const rows = buildRows({ rowCount: 8, cardsPerRow: 3 });
    const active = selectCenteredRowWindow(rows, rows[4]!.center, 12);

    assert.deepEqual(sortedIndices(active), [
      6, 7, 8,
      9, 10, 11,
      12, 13, 14,
      15, 16, 17,
    ]);
  });

  it("moves the active window down and back up as the viewport center changes", () => {
    const rows = buildRows({ rowCount: 9, cardsPerRow: 2 });
    const down = selectCenteredRowWindow(rows, rows[5]!.center, 12);
    const backUp = selectCenteredRowWindow(rows, rows[2]!.center, 12);

    assert.deepEqual(sortedIndices(down), [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]);
    assert.deepEqual(sortedIndices(backUp), [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]);
  });

  it("uses the nearest scrollable ancestor instead of window", () => {
    type FakeElement = {
      parentElement: FakeElement | null;
      clientHeight: number;
      scrollHeight: number;
    };

    const outer: FakeElement = {
      parentElement: null,
      clientHeight: 600,
      scrollHeight: 600,
    };
    const inner: FakeElement = {
      parentElement: outer,
      clientHeight: 480,
      scrollHeight: 1200,
    };
    const root: FakeElement = {
      parentElement: inner,
      clientHeight: 0,
      scrollHeight: 0,
    };

    const fallback = {} as Window;
    const scrollContainer = findNearestScrollContainer(root as unknown as HTMLElement, {
      fallback,
      getStyle: (element) => ({
        overflowY: (element as unknown as FakeElement) === inner ? "auto" : "visible",
      }),
    });

    assert.equal(scrollContainer, inner);
  });
});
