export type GalleryCardRect = {
  top: number;
  bottom: number;
};

export type GalleryRow = {
  indices: number[];
  top: number;
  bottom: number;
  center: number;
};

const DEFAULT_ROW_TOLERANCE_PX = 24;

function buildRow(indices: number[], top: number, bottom: number): GalleryRow {
  return {
    indices,
    top,
    bottom,
    center: top + (bottom - top) / 2,
  };
}

export function groupCardRectsIntoRows(
  rects: readonly GalleryCardRect[],
  tolerancePx = DEFAULT_ROW_TOLERANCE_PX,
): GalleryRow[] {
  const rows: GalleryRow[] = [];

  rects.forEach((rect, index) => {
    const previous = rows.at(-1);

    if (!previous || Math.abs(rect.top - previous.top) > tolerancePx) {
      rows.push(buildRow([index], rect.top, rect.bottom));
      return;
    }

    previous.indices.push(index);
    previous.top = Math.min(previous.top, rect.top);
    previous.bottom = Math.max(previous.bottom, rect.bottom);
    previous.center = previous.top + (previous.bottom - previous.top) / 2;
  });

  return rows;
}

export function selectCenteredRowWindow(
  rows: readonly GalleryRow[],
  viewportCenter: number,
  targetCardCount: number,
): Set<number> {
  const activeIndices = new Set<number>();
  if (rows.length === 0) return activeIndices;

  const totalCards = rows.reduce((sum, row) => sum + row.indices.length, 0);
  if (totalCards <= targetCardCount) {
    rows.forEach((row) => row.indices.forEach((index) => activeIndices.add(index)));
    return activeIndices;
  }

  let centerRowIndex = 0;
  let centerDistance = Number.POSITIVE_INFINITY;

  rows.forEach((row, index) => {
    const distance = Math.abs(row.center - viewportCenter);
    if (distance < centerDistance) {
      centerDistance = distance;
      centerRowIndex = index;
    }
  });

  let activeCount = 0;
  let previousIndex = centerRowIndex - 1;
  let nextIndex = centerRowIndex + 1;
  const selectedRows = new Set<number>([centerRowIndex]);

  rows[centerRowIndex]?.indices.forEach((index) => activeIndices.add(index));
  activeCount += rows[centerRowIndex]?.indices.length ?? 0;

  while (activeCount < targetCardCount && (previousIndex >= 0 || nextIndex < rows.length)) {
    const previousRow = previousIndex >= 0 ? rows[previousIndex] : null;
    const nextRow = nextIndex < rows.length ? rows[nextIndex] : null;

    if (!previousRow && !nextRow) break;

    const previousDistance = previousRow
      ? Math.abs(previousRow.center - viewportCenter)
      : Number.POSITIVE_INFINITY;
    const nextDistance = nextRow
      ? Math.abs(nextRow.center - viewportCenter)
      : Number.POSITIVE_INFINITY;

    const chosenIndex =
      previousDistance <= nextDistance ? previousIndex : nextIndex;

    if (chosenIndex < 0 || chosenIndex >= rows.length || selectedRows.has(chosenIndex)) {
      break;
    }

    selectedRows.add(chosenIndex);
    rows[chosenIndex]?.indices.forEach((index) => activeIndices.add(index));
    activeCount += rows[chosenIndex]?.indices.length ?? 0;

    if (chosenIndex === previousIndex) {
      previousIndex -= 1;
    } else {
      nextIndex += 1;
    }
  }

  return activeIndices;
}

function isScrollableOverflow(value: string | null | undefined): boolean {
  return value === "auto" || value === "scroll" || value === "overlay";
}

export function findNearestScrollContainer(
  root: HTMLElement,
  options?: {
    getStyle?: (element: HTMLElement) => { overflowY?: string | null };
    fallback?: Window;
  },
): HTMLElement | Window {
  const getStyle =
    options?.getStyle ??
    ((element: HTMLElement) => ({ overflowY: window.getComputedStyle(element).overflowY }));

  let current = root.parentElement;

  while (current) {
    const overflowY = getStyle(current).overflowY;
    if (isScrollableOverflow(overflowY) && current.scrollHeight > current.clientHeight) {
      return current;
    }
    current = current.parentElement;
  }

  return options?.fallback ?? window;
}
