/// The main RAG (Retrieval-Augmented Generation) pipeline orchestrator.
///
/// Coordinates the full RAG workflow:
/// 1. Embeds the user query.
/// 2. Retrieves relevant context chunks from the vector store.
/// 3. Builds a prompt combining the query with retrieved context.
/// 4. Sends the prompt to the LLM.
/// 5. Returns the response with source citations.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:logging/logging.dart';

import '../../core/models/message_model.dart';
import '../../core/models/vector_search_result.dart';
import '../embedding/embedding_generator.dart';
import '../retrieval/retrieval_config.dart';
import '../retrieval/vector_retriever.dart';

/// Result of a RAG pipeline execution.
class RagResponse {
  /// The generated response text.
  final String text;

  /// Source chunks that were used to generate the response.
  final List<VectorSearchResult> sources;

  /// IDs of the source chunks (for [MessageModel.sources]).
  List<String> get sourceIds => sources.map((s) => s.chunkId).toList();

  /// IDs of the source documents.
  List<String> get sourceDocumentIds =>
      sources.map((s) => s.documentId).toSet().toList();

  /// Whether the response was generated with retrieved context.
  bool get hasContext => sources.isNotEmpty;

  /// Total token count estimate for the response.
  final int? tokenCount;

  const RagResponse({
    required this.text,
    this.sources = const [],
    this.tokenCount,
  });

  /// Creates a response with no context (direct LLM answer).
  factory RagResponse.direct(String text) {
    return RagResponse(text: text);
  }

  /// Creates a response indicating no relevant context was found.
  factory RagResponse.noContext(String text) {
    return RagResponse(text: text, sources: []);
  }

  @override
  String toString() =>
      'RagResponse(text: ${text.substring(0, math.min(80, text.length))}..., '
      'sources: ${sources.length})';
}

/// Configuration for the RAG pipeline.
class RagPipelineConfig {
  /// The system prompt template used for RAG queries.
  ///
  /// Use `{context}` as a placeholder for the retrieved context,
  /// and `{question}` as a placeholder for the user's question.
  final String systemPromptTemplate;

  /// Maximum number of context chunks to include in the prompt.
  final int maxContextChunks;

  /// Maximum total characters of context to include.
  final int maxContextLength;

  /// Separator between context chunks in the prompt.
  final String contextSeparator;

  /// Whether to include source citations in the response.
  final bool includeCitations;

  const RagPipelineConfig({
    this.systemPromptTemplate = _defaultSystemPrompt,
    this.maxContextChunks = 5,
    this.maxContextLength = 4000,
    this.contextSeparator = '\n\n---\n\n',
    this.includeCitations = true,
  });

  /// Default system prompt for RAG.
  static const String _defaultSystemPrompt = '''
You are Zephyr, a helpful AI research assistant. Answer the user's question using only the provided context. 

If the context does not contain enough information to answer the question, say so honestly rather than making up information.

Be concise and accurate. Cite your sources when possible.

Context:
{context}

Question: {question}
''';

  /// Returns a copy with the specified fields replaced.
  RagPipelineConfig copyWith({
    String? systemPromptTemplate,
    int? maxContextChunks,
    int? maxContextLength,
    String? contextSeparator,
    bool? includeCitations,
  }) {
    return RagPipelineConfig(
      systemPromptTemplate: systemPromptTemplate ?? this.systemPromptTemplate,
      maxContextChunks: maxContextChunks ?? this.maxContextChunks,
      maxContextLength: maxContextLength ?? this.maxContextLength,
      contextSeparator: contextSeparator ?? this.contextSeparator,
      includeCitations: includeCitations ?? this.includeCitations,
    );
  }
}

/// The LLM interface that the RAG pipeline uses to generate responses.
///
/// Implement this to connect any LLM provider (Gemini, local models, etc.).
abstract class LlmProvider {
  /// Generates a response for the given [prompt].
  ///
  /// [systemPrompt] is the system-level instruction, and [prompt] is the
  /// user's message (which may include retrieved context).
  Future<String> generateResponse({
    required String systemPrompt,
    required String prompt,
  });

  /// Generates a streaming response, yielding tokens as they become available.
  ///
  /// Returns a [Stream] of text chunks that together form the complete response.
  Stream<String> generateStreamingResponse({
    required String systemPrompt,
    required String prompt,
  });
}

/// Orchestrates the complete RAG pipeline.
///
/// Usage:
/// ```dart
/// final pipeline = RagPipeline(
///   embeddingGenerator: myEmbedder,
///   retriever: myRetriever,
///   llmProvider: myLlm,
/// );
///
/// final response = await pipeline.query('What is the company revenue?');
/// print(response.text);
/// print(response.sources); // Source citations
/// ```
class RagPipeline {
  RagPipeline({
    required this.embeddingGenerator,
    required this.retriever,
    required this.llmProvider,
    RagPipelineConfig? config,
  }) : _config = config ?? const RagPipelineConfig();

  /// Generates embeddings for queries and documents.
  final EmbeddingGenerator embeddingGenerator;

  /// Performs vector similarity search over stored chunks.
  final VectorRetriever retriever;

  /// The LLM that generates the final response.
  final LlmProvider llmProvider;

  /// Pipeline configuration.
  final RagPipelineConfig _config;

  final Logger _logger = Logger('Zephyr.RAG.Pipeline');

  /// Executes the full RAG pipeline for a user query.
  ///
  /// 1. Embeds the query.
  /// 2. Retrieves relevant chunks.
  /// 3. Builds a context-augmented prompt.
  /// 4. Generates a response via the LLM.
  ///
  /// Returns a [RagResponse] with the answer and source citations.
  Future<RagResponse> query(
    String userQuery, {
    RetrievalConfig? retrievalConfig,
    Map<String, dynamic>? metadataFilters,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      // ── Step 1: Embed the query ─────────────────────────────────────
      _logger.fine('Step 1: Embedding query');
      final queryEmbedding = await embeddingGenerator.generateEmbedding(
        userQuery,
      );

      // ── Step 2: Retrieve relevant chunks ────────────────────────────
      _logger.fine('Step 2: Retrieving context');
      final effectiveConfig = retrievalConfig ??
          const RetrievalConfig().copyWith(
            metadataFilters: metadataFilters ?? const {},
          );

      final searchResults = await retriever.search(
        queryEmbedding,
        config: effectiveConfig,
      );

      final contextChunks = searchResults.map((s) => s.result).toList();

      if (contextChunks.isEmpty) {
        _logger.info('No relevant context found for query');
        // Still ask the LLM, but without context.
        final directResponse = await llmProvider.generateResponse(
          systemPrompt: _config.systemPromptTemplate
              .replaceAll('{context}', 'No relevant context found.')
              .replaceAll('{question}', userQuery),
          prompt: userQuery,
        );
        return RagResponse.noContext(directResponse);
      }

      // ── Step 3: Build the context-augmented prompt ──────────────────
      _logger.fine('Step 3: Building prompt with ${contextChunks.length} chunks');
      final contextText = _buildContext(contextChunks);

      final systemPrompt = _config.systemPromptTemplate
          .replaceAll('{context}', contextText)
          .replaceAll('{question}', userQuery);

      // ── Step 4: Generate the response ───────────────────────────────
      _logger.fine('Step 4: Generating response via LLM');
      final responseText = await llmProvider.generateResponse(
        systemPrompt: systemPrompt,
        prompt: userQuery,
      );

      stopwatch.stop();
      _logger.info(
        'RAG query completed in ${stopwatch.elapsedMilliseconds}ms '
        'with ${contextChunks.length} context chunks',
      );

      return RagResponse(
        text: responseText,
        sources: contextChunks,
      );
    } catch (e, st) {
      stopwatch.stop();
      _logger.severe('RAG pipeline failed after ${stopwatch.elapsedMilliseconds}ms', e, st);
      rethrow;
    }
  }

  /// Executes the RAG pipeline with streaming response.
  ///
  /// Yields response tokens as they are generated by the LLM.
  /// The final emission includes the complete [RagResponse].
  Stream<RagResponse> queryStreaming(
    String userQuery, {
    RetrievalConfig? retrievalConfig,
    Map<String, dynamic>? metadataFilters,
  }) async* {
    final stopwatch = Stopwatch()..start();

    try {
      // ── Step 1 & 2: Embed and retrieve (same as non-streaming) ──────
      final queryEmbedding = await embeddingGenerator.generateEmbedding(
        userQuery,
      );

      final effectiveConfig = retrievalConfig ??
          const RetrievalConfig().copyWith(
            metadataFilters: metadataFilters ?? const {},
          );

      final searchResults = await retriever.search(
        queryEmbedding,
        config: effectiveConfig,
      );

      final contextChunks = searchResults.map((s) => s.result).toList();

      final contextText = contextChunks.isEmpty
          ? 'No relevant context found.'
          : _buildContext(contextChunks);

      final systemPrompt = _config.systemPromptTemplate
          .replaceAll('{context}', contextText)
          .replaceAll('{question}', userQuery);

      // ── Step 3: Stream the LLM response ─────────────────────────────
      var accumulatedText = '';
      await for (final chunk in llmProvider.generateStreamingResponse(
        systemPrompt: systemPrompt,
        prompt: userQuery,
      )) {
        accumulatedText += chunk;
        yield RagResponse(
          text: accumulatedText,
          sources: contextChunks,
        );
      }

      stopwatch.stop();
      _logger.info(
        'Streaming RAG query completed in ${stopwatch.elapsedMilliseconds}ms',
      );
    } catch (e, st) {
      stopwatch.stop();
      _logger.severe('Streaming RAG pipeline failed', e, st);
      rethrow;
    }
  }

  /// Builds the context string from retrieved chunks.
  ///
  /// Respects [RagPipelineConfig.maxContextChunks] and
  /// [RagPipelineConfig.maxContextLength] to avoid exceeding
  /// the LLM's context window.
  String _buildContext(List<VectorSearchResult> chunks) {
    final limitedChunks = chunks.take(_config.maxContextChunks).toList();

    var totalLength = 0;
    final selectedChunks = <VectorSearchResult>[];

    for (final chunk in limitedChunks) {
      final chunkText = _formatChunk(chunk);
      if (totalLength + chunkText.length > _config.maxContextLength &&
          selectedChunks.isNotEmpty) {
        break;
      }
      selectedChunks.add(chunk);
      totalLength += chunkText.length;
    }

    return selectedChunks
        .map(_formatChunk)
        .join(_config.contextSeparator);
  }

  /// Formats a single chunk for inclusion in the prompt.
  String _formatChunk(VectorSearchResult chunk) {
    if (_config.includeCitations) {
      return '[Source: ${chunk.chunkId}] ${chunk.content}';
    }
    return chunk.content;
  }
}

