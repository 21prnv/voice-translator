import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_translator/google_translator.dart';
import 'package:translator/translator.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice Translation Chat',
      theme: ThemeData(
        primaryColor: Colors.teal,
        scaffoldBackgroundColor: Colors.grey[100],
        colorScheme: ColorScheme.light(
          primary: Colors.teal,
          secondary: Colors.amber,
          surface: Colors.white,
        ),
        textTheme: TextTheme(
          bodyMedium: TextStyle(fontSize: 16, color: Colors.grey[800]),
          titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[400]!),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: JoinRoomScreen(),
    );
  }
}

class JoinRoomScreen extends StatefulWidget {
  @override
  _JoinRoomScreenState createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final _roomIdController = TextEditingController();
  final _serverIpController = TextEditingController(text: '10.0.2.2');
  String? _fromLanguage;
  String? _toLanguage;
  bool _isLoading = false;

  final List<String> languages = [
    'English',
    'Hindi',
    'Spanish',
    'French',
    'German',
    'Marathi',
    'Tamil',
    'Telugu',
  ];

  void _joinRoom() async {
    if (_roomIdController.text.isNotEmpty &&
        _fromLanguage != null &&
        _toLanguage != null) {
      setState(() => _isLoading = true);
      await Future.delayed(Duration(milliseconds: 500));
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => ChatScreen(
                roomId: _roomIdController.text,
                fromLanguage: _fromLanguage!,
                toLanguage: _toLanguage!,
              ),
        ),
      ).then((_) => setState(() => _isLoading = false));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please fill all fields')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Walkie Talkie'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.0),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Enter Chat Details',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      SizedBox(height: 24),
                      TextFormField(
                        controller: _roomIdController,
                        decoration: InputDecoration(
                          labelText: 'Room ID',
                          prefixIcon: Icon(Icons.meeting_room),
                        ),
                      ),
                      SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'From Language',
                          prefixIcon: Icon(Icons.language),
                        ),
                        items:
                            languages
                                .map(
                                  (lang) => DropdownMenuItem(
                                    value: lang,
                                    child: Text(lang),
                                  ),
                                )
                                .toList(),
                        onChanged:
                            (value) => setState(() => _fromLanguage = value),
                      ),
                      SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'To Language',
                          prefixIcon: Icon(Icons.translate),
                        ),
                        items:
                            languages
                                .map(
                                  (lang) => DropdownMenuItem(
                                    value: lang,
                                    child: Text(lang),
                                  ),
                                )
                                .toList(),
                        onChanged:
                            (value) => setState(() => _toLanguage = value),
                      ),
                      SizedBox(height: 24),
                      AnimatedContainer(
                        duration: Duration(milliseconds: 300),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _joinRoom,
                          child: Text(
                            'Join Chat',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String roomId;
  final String fromLanguage;
  final String toLanguage;

  ChatScreen({
    required this.roomId,
    required this.fromLanguage,
    required this.toLanguage,
  });

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  IO.Socket? socket;
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final GoogleTranslator _translator = GoogleTranslator();
  final TextEditingController _textController = TextEditingController();
  final List<ChatMessage> _messages = [];
  String _currentText = '';
  String _translatedText = '';
  bool _isListening = false;
  bool _showSendButton = false;
  bool _isConnected = false;
  bool _isTranslating = false;
  bool _isConnecting = true;
  int _memberCount = 0;

  @override
  void initState() {
    super.initState();
    _initSocket();
    _initSpeech();
    _initTts();
  }

  void _initSocket() {
    const serverUrl = 'https://translator-socket.onrender.com/';
    socket = IO.io(serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'reconnection': true,
      'reconnectionAttempts': 10,
      'reconnectionDelay': 1000,
    });

    socket?.onConnect((_) {
      setState(() {
        _isConnected = true;
        _isConnecting = false;
      });
      socket?.emit('joinRoom', widget.roomId);
      _showConnectionStatus('Connected to server');
    });

    socket?.onConnectError((error) {
      setState(() {
        _isConnected = false;
        _isConnecting = false;
      });
      _showConnectionStatus('Connection error: $error');
    });

    socket?.onError((error) {
      _showConnectionStatus('Socket error: $error');
    });

    socket?.onDisconnect((_) {
      setState(() {
        _isConnected = false;
        _isConnecting = false;
        _memberCount = 0;
      });
      _showConnectionStatus('Disconnected from server');
    });

    socket?.on('message', (data) {
      setState(() {
        final message = ChatMessage(
          id: Uuid().v4(),
          originalText: data['originalText'],
          translatedText: data['translatedText'],
          originalLanguage: data['originalLanguage'],
          translatedLanguage: widget.toLanguage,
          timestamp: DateTime.now(),
          isMe: data['socketId'] == socket?.id,
        );
        _messages.add(message);
        _speak(message.translatedText);
      });
    });

    socket?.on('memberCount', (count) {
      setState(() => _memberCount = count);
    });
  }

  void _showConnectionStatus(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            message.contains('error') || message.contains('Disconnected')
                ? Colors.red
                : Colors.green,
      ),
    );
  }

  void _initSpeech() async {
    bool available = await _speech.initialize();
    if (!available) {
      _showConnectionStatus('Speech recognition not available');
    }
  }

  void _initTts() async {
    await _tts.setLanguage(_languageCode(widget.toLanguage));
    await _tts.setSpeechRate(0.5);
  }

  String _languageCode(String language) {
    switch (language) {
      case 'English':
        return 'en';
      case 'Hindi':
        return 'hi';
      case 'Spanish':
        return 'es';
      case 'French':
        return 'fr';
      case 'German':
        return 'de';
      case 'Marathi':
        return 'mr';
      case 'Tamil':
        return 'ta';
      case 'Telugu':
        return 'te';
      default:
        return 'en';
    }
  }

  Future<String> _translate(String text, String from, String to) async {
    try {
      setState(() => _isTranslating = true);
      final translation = await _translator.translate(
        text,
        from: _languageCode(from),
        to: _languageCode(to),
      );
      setState(() => _isTranslating = false);
      return translation.text;
    } catch (e) {
      setState(() => _isTranslating = false);
      return 'Translation failed: $e';
    }
  }

  void _speak(String text) async {
    await _tts.speak(text);
  }

  void _startListening() async {
    HapticFeedback.lightImpact();
    setState(() {
      _isListening = true;
      _currentText = '';
      _translatedText = '';
    });

    await _speech.listen(
      onResult: (result) async {
        if (result.finalResult) {
          setState(() {
            _isListening = false;
          });

          // First translate to fromLanguage if needed
          String originalText = result.recognizedWords;
          // Detect language by translating with 'auto' and checking the source language code
          final translation = await _translator.translate(
            originalText,
            from: 'auto',
            to: _languageCode(widget.fromLanguage),
          );
          String detectedLanguage =
              translation.sourceLanguage?.code ??
              _languageCode(widget.fromLanguage);

          if (detectedLanguage != _languageCode(widget.fromLanguage)) {
            originalText = translation.text;
          }

          setState(() => _currentText = originalText);

          // Then translate to target language
          final translated = await _translate(
            originalText,
            widget.fromLanguage,
            widget.toLanguage,
          );

          setState(() {
            _translatedText = translated;
            _showSendButton = true;
          });
        } else {
          setState(() {
            _currentText = result.recognizedWords;
          });
        }
      },
      localeId: _languageCode(widget.fromLanguage),
    );
  }

  void _stopListening() async {
    HapticFeedback.lightImpact();
    await _speech.stop();
    setState(() => _isListening = false);
  }

  void _sendMessage() {
    HapticFeedback.lightImpact();
    if (_translatedText.isNotEmpty) {
      if (socket?.connected ?? false) {
        socket?.emit('message', {
          'roomId': widget.roomId,
          'originalText': _currentText,
          'translatedText': _translatedText,
          'originalLanguage': widget.fromLanguage,
          'socketId': socket?.id,
        });
      } else {
        _showConnectionStatus('Cannot send message: Not connected to server');
      }

      setState(() {
        _currentText = '';
        _translatedText = '';
        _showSendButton = false;
      });
    }
  }

  void _sendTypedMessage() async {
    if (_textController.text.isNotEmpty) {
      HapticFeedback.lightImpact();
      final inputText = _textController.text;

      if (socket?.connected ?? false) {
        setState(() => _isTranslating = true);

        // First, detect the language of input text using translation with 'auto'
        final translation = await _translator.translate(
          inputText,
          from: 'auto',
          to: _languageCode(widget.fromLanguage),
        );
        String detectedLanguage =
            translation.sourceLanguage?.code ??
            _languageCode(widget.fromLanguage);

        // If input is not in fromLanguage, translate it to fromLanguage first
        String originalText = inputText;
        if (detectedLanguage != _languageCode(widget.fromLanguage)) {
          originalText = translation.text;
        }

        // Then translate to target language
        final translatedText = await _translate(
          originalText,
          widget.fromLanguage,
          widget.toLanguage,
        );

        socket?.emit('message', {
          'roomId': widget.roomId,
          'originalText': originalText,
          'translatedText': translatedText,
          'originalLanguage': widget.fromLanguage,
          'socketId': socket?.id,
        });

        setState(() {
          _textController.clear();
          _isTranslating = false;
        });
      } else {
        _showConnectionStatus('Cannot send message: Not connected to server');
      }
    }
  }

  void _reconnectSocket() {
    setState(() => _isConnecting = true);
    socket?.connect();
    _showConnectionStatus('Attempting to reconnect...');
  }

  @override
  void dispose() {
    _textController.dispose();
    socket?.disconnect();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat: ${widget.roomId}'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  child: CircleAvatar(
                    radius: 6,
                    backgroundColor: _isConnected ? Colors.green : Colors.red,
                  ),
                ),
                SizedBox(width: 8),
                Text(_isConnected ? 'Connected' : 'Disconnected'),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (!_isConnected && !_isConnecting)
                Container(
                  color: Colors.red[50],
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red[900]),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Not connected to server. Messages will not be sent.',
                          style: TextStyle(color: Colors.red[900]),
                        ),
                      ),
                      TextButton(
                        onPressed: _reconnectSocket,
                        child: Text(
                          'Reconnect',
                          style: TextStyle(color: Colors.teal),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    return AnimatedSlide(
                      duration: Duration(milliseconds: 300),
                      offset: Offset(0, 0.1),
                      child: ChatBubble(message: message, onSpeak: _speak),
                    );
                  },
                ),
              ),
              if (_currentText.isNotEmpty || _translatedText.isNotEmpty)
                Container(
                  color: Colors.grey[50],
                  padding: EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.fromLanguage}: $_currentText',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${widget.toLanguage}: $_translatedText',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (_isTranslating)
                        Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('Translating...'),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              Padding(
                padding: EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            decoration: InputDecoration(
                              hintText: 'Type your message...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            onSubmitted: (_) => _sendTypedMessage(),
                          ),
                        ),
                        SizedBox(width: 8),
                        FloatingActionButton.small(
                          onPressed: _sendTypedMessage,
                          backgroundColor: Colors.amber,
                          child: Icon(Icons.send),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        FloatingActionButton(
                          onPressed:
                              _isListening ? _stopListening : _startListening,
                          backgroundColor:
                              _isListening ? Colors.red : Colors.teal,
                          child: AnimatedSwitcher(
                            duration: Duration(milliseconds: 200),
                            child: Icon(
                              _isListening ? Icons.stop : Icons.mic,
                              key: ValueKey<bool>(_isListening),
                            ),
                          ),
                        ),
                        if (_showSendButton) ...[
                          SizedBox(width: 12),
                          FloatingActionButton(
                            onPressed: _sendMessage,
                            backgroundColor: Colors.amber,
                            child: Icon(Icons.send),
                          ),
                          SizedBox(width: 8),
                          FloatingActionButton(
                            onPressed: () {
                              setState(() {
                                _currentText = '';
                                _translatedText = '';
                                _showSendButton = false;
                              });
                            },
                            backgroundColor: Colors.red,
                            child: Icon(Icons.close),
                          ),
                        ],
                        SizedBox(width: 12),
                        FloatingActionButton.small(
                          onPressed: () {
                            if (socket?.connected ?? false) {
                              _showConnectionStatus(
                                'Socket is connected with ID: ${socket?.id}',
                              );
                            } else {
                              _showConnectionStatus('Socket is not connected');
                            }
                          },
                          backgroundColor: Colors.grey[300],
                          child: Icon(
                            Icons.info_outline,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_isConnecting)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Connecting to server...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String id;
  final String originalText;
  final String translatedText;
  final String originalLanguage;
  final String translatedLanguage;
  final DateTime timestamp;
  final bool isMe;

  ChatMessage({
    required this.id,
    required this.originalText,
    required this.translatedText,
    required this.originalLanguage,
    required this.translatedLanguage,
    required this.timestamp,
    required this.isMe,
  });
}

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final Function(String) onSpeak;

  ChatBubble({required this.message, required this.onSpeak});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Card(
          elevation: 4,
          shadowColor: Colors.teal.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors:
                    message.isMe
                        ? [Colors.teal[400]!, Colors.teal[600]!]
                        : [Colors.grey[200]!, Colors.grey[300]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(2, 2),
                ),
              ],
            ),
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor:
                          message.isMe ? Colors.teal[800] : Colors.grey[600],
                      child: Text(
                        message.isMe ? 'Me' : 'Other',
                        style: TextStyle(fontSize: 10, color: Colors.white),
                      ),
                    ),
                    SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        Icons.volume_up,
                        size: 20,
                        color: message.isMe ? Colors.white70 : Colors.teal,
                      ),
                      onPressed: () => onSpeak(message.translatedText),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  '${message.originalLanguage}: ${message.originalText}',
                  style: TextStyle(
                    fontSize: 14,
                    color: message.isMe ? Colors.white70 : Colors.grey[800],
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: message.isMe ? Colors.teal[800] : Colors.teal[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${message.translatedLanguage}: ${message.translatedText}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: message.isMe ? Colors.white : Colors.teal[900],
                    ),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '${message.timestamp.hour}:${message.timestamp.minute}',
                  style: TextStyle(
                    fontSize: 12,
                    color: message.isMe ? Colors.white54 : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
