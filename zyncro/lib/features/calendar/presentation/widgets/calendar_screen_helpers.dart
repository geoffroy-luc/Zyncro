import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zyncro/core/utils/color_hex.dart';
import 'package:zyncro/features/calendar/domain/entities/event.dart';

const calendarDefaultEventColor = Color(0xFF4F7CFF);

Color calendarEventColor(Event e) =>
    tryHexToColor(e.color) ?? calendarDefaultEventColor;

String calendarTimeLabel(DateTime dt) => DateFormat('HH:mm').format(dt);
