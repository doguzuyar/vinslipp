import type { NextConfig } from "next";

const isProd = process.env.NODE_ENV === "production";
const isCapacitor = process.env.BUILD_TARGET === "capacitor";

const nextConfig: NextConfig = {
  output: "export",
  basePath: isProd && !isCapacitor ? "/vinslipp" : "",
  images: { unoptimized: true },
};

export default nextConfig;
