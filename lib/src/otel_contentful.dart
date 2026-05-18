// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_contentful_suppression.dart';

const _tracerName = 'dartastic_otel_libs_contentful';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

class ContentfulResult {
  const ContentfulResult({
    this.itemCount,
    this.total,
    this.skip,
    this.limit,
    this.includes,
    this.contentType,
    this.environment,
    this.locale,
    this.cacheHit,
    this.requestId,
    this.rateLimitRemaining,
    this.statusCode,
  });

  /// `items.length` — items returned by this call.
  final int? itemCount;

  /// `total` — total matching records (use with skip/limit to detect
  /// pagination thrash).
  final int? total;

  final int? skip;
  final int? limit;

  /// Number of linked entries inlined via `?include=N`.
  final int? includes;

  /// `sys.contentType.sys.id` — slice by type.
  final String? contentType;

  /// Contentful environment (`master`, `staging`, etc.) — primary cost
  /// dim, environments are billed.
  final String? environment;

  /// `sys.locale` if single-locale request.
  final String? locale;

  /// `X-Contentful-Cache: HIT|MISS|REVALIDATED`.
  final bool? cacheHit;

  /// `X-Contentful-Request-Id`.
  final String? requestId;

  /// `X-Contentful-RateLimit-Reset` paired with the remaining bucket.
  final int? rateLimitRemaining;

  final int? statusCode;
}

class ContentfulCallResult<T> {
  const ContentfulCallResult({required this.value, this.result});
  final T value;
  final ContentfulResult? result;
}

/// Wraps a Contentful API call in a CLIENT span. [api] is one of
/// `cda` (Content Delivery), `cma` (Content Management), `preview`,
/// `graphql`, `images`, `assets`.
Future<T> tracedContentful<T>({
  required String api,
  required String operation,
  required Future<ContentfulCallResult<T>> Function() invoke,
  String? spaceId,
}) async {
  if (contentfulInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'contentful',
    'rpc.method': operation,
    'contentful.api': api,
    'contentful.operation': operation,
  };
  if (spaceId != null) m['contentful.space.id'] = spaceId;

  final span = _tracer().startSpan(
    'contentful $api.$operation',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.itemCount != null) {
        extras.add(OTel.attributeInt(
          'contentful.item_count',
          r.result!.itemCount!,
        ));
      }
      if (r.result!.total != null) {
        extras.add(OTel.attributeInt('contentful.total', r.result!.total!));
      }
      if (r.result!.skip != null) {
        extras.add(OTel.attributeInt('contentful.skip', r.result!.skip!));
      }
      if (r.result!.limit != null) {
        extras.add(OTel.attributeInt('contentful.limit', r.result!.limit!));
      }
      if (r.result!.includes != null) {
        extras.add(OTel.attributeInt(
          'contentful.includes',
          r.result!.includes!,
        ));
      }
      if (r.result!.contentType != null) {
        extras.add(OTel.attributeString(
          'contentful.content_type',
          r.result!.contentType!,
        ));
      }
      if (r.result!.environment != null) {
        extras.add(OTel.attributeString(
          'contentful.environment',
          r.result!.environment!,
        ));
      }
      if (r.result!.locale != null) {
        extras.add(OTel.attributeString(
          'contentful.locale',
          r.result!.locale!,
        ));
      }
      if (r.result!.cacheHit != null) {
        extras.add(OTel.attributeBool(
          'contentful.cache.hit',
          r.result!.cacheHit!,
        ));
      }
      if (r.result!.requestId != null) {
        extras.add(OTel.attributeString(
          'contentful.request.id',
          r.result!.requestId!,
        ));
      }
      if (r.result!.rateLimitRemaining != null) {
        extras.add(OTel.attributeInt(
          'contentful.rate_limit.remaining',
          r.result!.rateLimitRemaining!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTel.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'Contentful HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTel.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
