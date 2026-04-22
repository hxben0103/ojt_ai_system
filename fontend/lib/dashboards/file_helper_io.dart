// File helper for platforms with dart:io (mobile, desktop)
import 'dart:io';
import 'package:flutter/material.dart';

dynamic createFile(String path) => File(path);
Future<bool> fileExists(dynamic file) async => await (file as File).exists();
ImageProvider? createImageProvider(dynamic file) => FileImage(file as File);


