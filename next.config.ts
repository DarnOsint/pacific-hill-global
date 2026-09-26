import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  typedRoutes: true,

  // Pin the workspace root so Turbopack does not walk up to /Users/macbook and
  // try to resolve dependencies outside the repository. Without this, builds
  // warn about package-lock.json living outside the project.
  turbopack: {
    root: __dirname,
  },
};

export default nextConfig;
