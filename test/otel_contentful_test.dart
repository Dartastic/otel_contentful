// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_contentful/otel_contentful.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_contentful-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('cda entries call records env + includes + cache', () async {
    await tracedContentful<String>(
      api: 'cda',
      operation: 'entries.list',
      spaceId: 'sp-1',
      invoke: () async => const ContentfulCallResult(
        value: 'ok',
        result: ContentfulResult(
          itemCount: 25,
          total: 100,
          skip: 0,
          limit: 25,
          includes: 4,
          contentType: 'blogPost',
          environment: 'master',
          locale: 'en-US',
          cacheHit: true,
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('contentful cda.entries.list')!);
    expect(a['contentful.api'], 'cda');
    expect(a['contentful.environment'], 'master');
    expect(a['contentful.content_type'], 'blogPost');
    expect(a['contentful.includes'], 4);
    expect(a['contentful.cache.hit'], true);
    expect(a['contentful.total'], 100);
  });

  test('429 maps to span error', () async {
    await tracedContentful<String>(
      api: 'cma',
      operation: 'entries.create',
      invoke: () async => const ContentfulCallResult(
        value: 'ok',
        result: ContentfulResult(statusCode: 429, rateLimitRemaining: 0),
      ),
    );
    final s = spans.findSpanByName('contentful cma.entries.create')!;
    expect(s.status, SpanStatusCode.Error);
    final a = attrsOf(s);
    expect(a['contentful.rate_limit.remaining'], 0);
  });

  test('suppression skips spans', () async {
    await runWithoutContentfulInstrumentationAsync(() async {
      await tracedContentful<String>(
        api: 'cda',
        operation: 'entries.list',
        invoke: () async => const ContentfulCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('contentful '), isEmpty);
  });
}
