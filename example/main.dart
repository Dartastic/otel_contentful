// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_contentful/otel_contentful.dart';

/// Traces Contentful calls with OpenTelemetry.
///
/// `otel_contentful` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each Contentful call in
/// [tracedContentful]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'contentful-example');

  // Wraps a Contentful API call in a CLIENT span.
  final contentfulId = await tracedContentful<String>(
    api: 'cda',
    operation: 'create',
    spaceId: 'space_8f3a2c',
    invoke: () async {
      // Make the Contentful call here, then report what it returned.
      const id = 'contentful_8f3a2c';
      return const ContentfulCallResult(
          value: id,
          result: ContentfulResult(
              itemCount: 3,
              total: 1,
              skip: 1,
              limit: 25,
              includes: 1,
              contentType: 'sys.contentType.sys.id',
              environment: 'master',
              locale: 'sys.locale',
              cacheHit: true,
              requestId: 'request_8f3a2c',
              rateLimitRemaining: 25,
              statusCode: 201));
    },
  );
  OTelLog.info('tracedContentful create returned $contentfulId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutContentfulInstrumentationAsync.
  await runWithoutContentfulInstrumentationAsync(
    () => tracedContentful<String>(
      api: 'cda',
      operation: 'create',
      spaceId: 'space_8f3a2c',
      invoke: () async {
        const id = 'contentful_8f3a2c';
        return const ContentfulCallResult(
            value: id,
            result: ContentfulResult(
                itemCount: 3,
                total: 1,
                skip: 1,
                limit: 25,
                includes: 1,
                contentType: 'sys.contentType.sys.id',
                environment: 'master',
                locale: 'sys.locale',
                cacheHit: true,
                requestId: 'request_8f3a2c',
                rateLimitRemaining: 25,
                statusCode: 201));
      },
    ),
  );

  await OTel.shutdown();
}
