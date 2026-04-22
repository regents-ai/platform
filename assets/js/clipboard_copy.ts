type CopyRuntime = Pick<typeof window, "clearTimeout" | "setTimeout"> & {
  navigator: Pick<Navigator, "clipboard">;
};

function getRuntime(): CopyRuntime {
  return window;
}

export function mountClipboardCopy(
  button: HTMLButtonElement,
  runtime: CopyRuntime = getRuntime(),
): () => void {
  let copyReset: number | undefined;

  const resetCopied = () => {
    button.dataset.copied = "false";
    copyReset = undefined;
  };

  const onClick = () => {
    const copyText = button.dataset.copyText ?? "";

    if (!copyText) return;

    void runtime.navigator.clipboard.writeText(copyText).then(() => {
      if (copyReset) runtime.clearTimeout(copyReset);
      button.dataset.copied = "true";
      copyReset = runtime.setTimeout(resetCopied, 1400);
    });
  };

  button.addEventListener("click", onClick);

  return () => {
    if (copyReset) runtime.clearTimeout(copyReset);
    button.removeEventListener("click", onClick);
  };
}
