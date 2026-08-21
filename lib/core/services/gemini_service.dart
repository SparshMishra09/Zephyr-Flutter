/// Gemini AI service wrapper around the `google_generative_ai` package.
///
/// Provides chat, streaming, embedding, and summarisation capabilities
/// backed by Google's Gemini models. All public methods throw
/// [GeminiAPIException] on failure so callers can handle errors uniformly.
library;

import 'dart:async';
import 'package:google_generative_ai/google_generative_ai.dart' as ggen;
import 'package:logging/logging.dart';

import '../utils/logger.dart';

final _logger = Logger('Zephyr.Gemini');

// ── Exceptions ────────────────────────────────────────────────────────

/// Thrown when a Gemini API call fails for any reason.
///
/// Wraps the original exception so callers can distinguish Gemini errors
/// from unrelated failures.
class GeminiAPIException implements Exception {
  /// Human-readable description of what went wrong.
  final String message;

  /// The underlying cause, if available.
  final Object? cause;

  /// HTTP status code returned by the API (null when not applicable).
  final int? statusCode;

  const GeminiAPIException({
    required this.message,
    this.cause,
    this.statusCode,
  });

  @override
  String toString() => 'GeminiAPIException: $message${cause != null ? ' (caused by $cause)' : ''}';
}

// ── Service ───────────────────────────────────────────────────────────

/// Service that wraps the Google Generative AI SDK.
///
/// Construct once at app startup with a valid API key and share the
/// instance across features.
class GeminiService {
  /// The API key used to authenticate requests.
  final String apiKey;

  /// The model identifier used for chat and summarisation.
  final String chatModelName;

  /// The model identifier used for embeddings.
  final String embeddingModelName;

  /// Lazily initialised chat model instance.
  ggen.GenerativeModel? _chatModel;

  /// Lazily initialised embedding model instance.
  ggen.GenerativeModel? _embeddingModel;

  GeminiService({
    required this.apiKey,
    this.chatModelName = 'gemini-1.5-flash',
    this.embeddingModelName = 'gemini-1.5-flash',
  }) {
    _logger.info('GeminiService initialised (chat: $chatModelName, embed: $embeddingModelName)');
  }

  // ── Internal helpers ────────────────────────────────────────────────

  ggen.GenerativeModel get _resolvedChatModel {
    _chatModel ??= ggen.GenerativeModel(
      model: chatModelName,
      apiKey: apiKey,
      generationConfig: const ggen.GenerationConfig(
        temperature: 0.7,
        topP: 0.95,
        topK: 40,
        maxOutputTokens: 4096,
      ),
      safetySettings: const [
        ggen.SafetySetting(
          ggen.HarmCategory.harassment,
          ggen.HarmBlockThreshold.medium,
        ),
        ggen.SafetySetting(
          ggen.HarmCategory.hateSpeech,
          ggen.HarmBlockThreshold.medium,
        ),
        ggen.SafetySetting(
          ggen.HarmCategory.sexuallyExplicit,
          ggen.HarmBlockThreshold.medium,
        ),
        ggen.SafetySetting(
          ggen.HarmCategory.dangerousContent,
          ggen.HarmBlockThreshold.medium,
        ),
      ],
    );
    return _chatModel!;
  }

  ggen.GenerativeModel get _resolvedEmbeddingModel {
    _embeddingModel ??= ggen.GenerativeModel(
      model: embeddingModelName,
      apiKey: apiKey,
    );
    return _embeddingModel!;
  }

  /// Builds the list of [ggen.Content] objects from an optional context
  /// history and the current user message.
  List<ggen.Content> _buildContents(
    String message, {
    List<String>? context,
  }) {
    final contents = <ggen.Content>[];

    // Prepend any context turns as user/assistant alternation.
    if (context != null && context.isNotEmpty) {
      for (final turn in context) {
        contents.add(ggen.Content.text(turn));
      }
    }

    // Append the current user message.
    contents.add(ggen.Content.text(message));
    return contents;
  }

  // ── Public API ──────────────────────────────────────────────────────

  /// Sends a chat message to Gemini and returns the full text response.
  ///
  /// [context] is an optional list of prior messages that will be sent
  /// as conversation history before [message].
  ///
  /// Throws [GeminiAPIException] on any error.
  Future<String> chat(String message, {List<String>? context}) async {
    if (message.trim().isEmpty) {
      throw const GeminiAPIException(message: 'Message cannot be empty');
    }

    try {
      _logger.fine('Sending chat request (${message.length} chars)');
      final model = _resolvedChatModel;
      final contents = _buildContents(message, context: context);

      final response = await model.generateContent(contents);
      final text = response.text?.trim() ?? '';

      if (text.isEmpty) {
        _logger.warning('Gemini returned an empty response');
      } else {
        _logger.fine('Chat response received (${text.length} chars)');
      }

      return text;
    } on ggen.InvalidApiKeyException catch (e) {
      _logger.severe('Invalid Gemini API key', e);
      throw GeminiAPIException(
        message: 'Invalid API key. Please check your settings.',
        cause: e,
        statusCode: 400,
      );
    } on ggen.APIException catch (e) {
      _logger.severe('Gemini API error: ${e.message}', e);
      throw GeminiAPIException(
        message: 'API error: ${e.message}',
        cause: e,
        statusCode: e.statusCode,
      );
    } catch (e, stack) {
      _logger.severe('Unexpected error during chat', e, stack);
      throw GeminiAPIException(
        message: 'Failed to get response: $e',
        cause: e,
      );
    }
  }

  /// Streams a chat response from Gemini token-by-token.
  ///
  /// Each event on the returned [Stream] is a text chunk. Concatenating
  /// all chunks yields the complete response.
  ///
  /// [context] works the same as in [chat].
  ///
  /// Errors are emitted as error events on the stream rather than thrown.
  Stream<String> streamChat(String message, {List<String>? context}) async* {
    if (message.trim().isEmpty) {
      yield* Stream.error(
        const GeminiAPIException(message: 'Message cannot be empty'),
      );
      return;
    }

    try {
      _logger.fine('Starting streaming chat request');
      final model = _resolvedChatModel;
      final contents = _buildContents(message, context: context);

      final stream = model.generateContentStream(contents);

      await for (final chunk in stream) {
        final text = chunk.text;
        if (text != null && text.isNotEmpty) {
          yield text;
        }
      }

      _logger.fine('Streaming chat complete');
    } on ggen.InvalidApiKeyException catch (e) {
      _logger.severe('Invalid API key during stream', e);
      yield* Stream.error(
        GeminiAPIException(
          message: 'Invalid API key. Please check your settings.',
          cause: e,
          statusCode: 400,
        ),
      );
    } on ggen.APIException catch (e) {
      _logger.severe('Gemini API stream error: ${e.message}', e);
      yield* Stream.error(
        GeminiAPIException(
          message: 'API error: ${e.message}',
          cause: e,
          statusCode: e.statusCode,
        ),
      );
    } catch (e, stack) {
      _logger.severe('Unexpected error during streaming chat', e, stack);
      yield* Stream.error(
        GeminiAPIException(
          message: 'Streaming failed: $e',
          cause: e,
        ),
      );
    }
  }

  /// Generates a vector embedding for the given [text].
  ///
  /// Returns a list of doubles representing the embedding vector.
  /// The dimensionality depends on the configured embedding model.
  ///
  /// Throws [GeminiAPIException] on any error.
  Future<List<double>> generateEmbedding(String text) async {
    if (text.trim().isEmpty) {
      throw const GeminiAPIException(message: 'Text cannot be empty');
    }

    try {
      _logger.fine('Generating embedding for ${text.length} chars');
      final model = _resolvedEmbeddingModel;

      final response = await model.embedContent(text);
      final embedding = response.embedding.values;

      _logger.fine('Embedding generated (${embedding.length} dimensions)');
      return embedding;
    } on ggen.APIException catch (e) {
      _logger.severe('Gemini embedding API error: ${e.message}', e);
      throw GeminiAPIException(
        message: 'Embedding API error: ${e.message}',
        cause: e,
        statusCode: e.statusCode,
      );
    } catch (e, stack) {
      _logger.severe('Unexpected error during embedding', e, stack);
      throw GeminiAPIException(
        message: 'Failed to generate embedding: $e',
        cause: e,
      );
    }
  }

  /// Summarises the given [text] using Gemini.
  ///
  /// Sends a system prompt asking the model to produce a concise summary.
  ///
  /// Throws [GeminiAPIException] on any error.
  Future<String> summarize(String text) async {
    if (text.trim().isEmpty) {
      throw const GeminiAPIException(message: 'Text cannot be empty');
    }

    const summaryPrompt =
        'Summarise the following text concisely in 2-4 sentences. '
        'Preserve the key points and main conclusions:\n\n';

    try {
      _logger.fine('Summarising ${text.length} chars');
      final model = _resolvedChatModel;

      final response = await model.generateContent(
        [ggen.Content.text(summaryPrompt + text)],
      );

      final summary = response.text?.trim() ?? '';

      if (summary.isEmpty) {
        _logger.warning('Gemini returned an empty summary');
      } else {
        _logger.fine('Summary generated (${summary.length} chars)');
      }

      return summary;
    } on ggen.APIException catch (e) {
      _logger.severe('Gemini summarisation error: ${e.message}', e);
      throw GeminiAPIException(
        message: 'Summarisation API error: ${e.message}',
        cause: e,
        statusCode: e.statusCode,
      );
    } catch (e, stack) {
      _logger.severe('Unexpected error during summarisation', e, stack);
      throw GeminiAPIException(
        message: 'Failed to summarise: $e',
        cause: e,
      );
    }
  }

  /// Resets the lazy model instances.
  ///
  /// Useful when the API key has been changed at runtime.
  void resetModels() {
    _chatModel = null;
    _embeddingModel = null;
    _logger.info('Gemini model instances cleared');
  }
}