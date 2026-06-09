import path from 'node:path';
import { PHASE_DEVELOPMENT_SERVER } from 'next/constants';
import type { NextConfig } from "next";

const contentSecurityPolicyReportOnly = [
  "default-src 'self'",
  "base-uri 'self'",
  "object-src 'none'",
  "frame-ancestors 'self'",
  "img-src 'self' data: blob: https:",
  "font-src 'self' data: https://fonts.gstatic.com",
  "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
  "script-src 'self' 'unsafe-inline' 'unsafe-eval'",
  "connect-src 'self' https: wss:",
  "worker-src 'self' blob:",
  "manifest-src 'self'",
  "form-action 'self'",
  "upgrade-insecure-requests",
].join('; ');

const securityHeaders = [
  {
    key: 'Strict-Transport-Security',
    value: 'max-age=63072000; includeSubDomains; preload',
  },
  {
    key: 'X-Content-Type-Options',
    value: 'nosniff',
  },
  {
    key: 'X-Frame-Options',
    value: 'SAMEORIGIN',
  },
  {
    key: 'Referrer-Policy',
    value: 'strict-origin-when-cross-origin',
  },
  {
    key: 'Permissions-Policy',
    value: 'camera=(), microphone=(), geolocation=(), payment=(), usb=(), bluetooth=(), serial=()',
  },
  {
    key: 'Content-Security-Policy-Report-Only',
    value: contentSecurityPolicyReportOnly,
  },
];

const nextConfig = (phase: string): NextConfig => ({
  output: 'standalone',
  ...(phase === PHASE_DEVELOPMENT_SERVER
    ? {}
    : {
        outputFileTracingRoot: path.resolve(process.cwd(), '..'),
        outputFileTracingIncludes: {
          '/*': ['../docs/**/*'],
        },
      }),
  async redirects() {
    return [
      {
        source: '/settings/language-region',
        destination: '/settings/language',
        permanent: true,
      },
    ];
  },
  async headers() {
    return [
      {
        source: '/docs/:path*',
        headers: [
          {
            key: 'Cache-Control',
            value: 'public, max-age=31536000, immutable',
          },
        ],
      },
      {
        source: '/landing/:path*',
        headers: [
          {
            key: 'Cache-Control',
            value: 'public, max-age=31536000, immutable',
          },
        ],
      },
      {
        source: '/(.*)',
        headers: securityHeaders,
      },
    ];
  },
});

export default nextConfig;
