# Gemini Integration

This project uses Google's Gemini API for AI capabilities. The implementation uses the official `google_generative_ai` package.

## Setup

1. Get a Gemini API key from the [Google AI Studio](https://ai.google.dev/)
2. Add your API key to `lib/core/config/api_keys.dart`

## Components

### 1. GeminiService (`lib/services/gemini_service.dart`)

A singleton service that provides direct access to Gemini API with methods:
- `generateText(prompt)`: Generate text from a text prompt
- `streamGenerateText(prompt)`: Stream text generation for real-time feedback
- `generateFromImage(prompt, imageBytes)`: Generate text from text + image input
- `startChat()`: Create a chat session for conversations

### 2. AiService (`lib/services/ai_service.dart`)

A more comprehensive service that provides additional business-specific features:
- SMS analysis
- Financial insights
- Message categorization
- Seamless chat capabilities

### 3. UI Screens

- `GeminiChatScreen`: A simple chat interface for conversations with Gemini
- `GeminiTestScreen`: A testing screen for various AI capabilities

## Usage Example

```dart
// Get text response
final geminiService = GeminiService();
final response = await geminiService.generateText("What is the capital of France?");

// Stream response
geminiService.streamGenerateText("Tell me a story").listen((chunk) {
  print(chunk); // Process each chunk of the response as it arrives
});

// Chat conversation
final chatSession = geminiService.startChat();
final response = await chatSession.sendMessage(Content.text("Hello, how are you?"));
```

## Security Considerations

- This implementation stores the API key directly in the app for simplicity
- For production, consider using secure storage, environment variables, or a backend proxy 