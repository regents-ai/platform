declare module "phoenix" {
  export class Socket {
    constructor(endpoint: string, opts?: unknown);
  }
}

declare module "qrcode" {
  const QRCode: {
    toDataURL(text: string, options?: unknown): Promise<string>;
  };

  export default QRCode;
}
