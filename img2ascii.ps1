import pygame
import sys
import random
import string
import asyncio
import math
import os
import json
import re
from datetime import datetime
from telegram import Bot, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.error import TelegramError

# === Инициализация Pygame ===
pygame.init()
pygame.mixer.init(frequency=44100, size=-16, channels=2, buffer=512)
clock = pygame.time.Clock()

# === Глобальные параметры ===
WIDTH, HEIGHT = 780, 920
BG_COLOR = (255, 250, 248)          # Теплый кремовый фон
TEXT_COLOR = (70, 60, 80)           # Глубокий фиолетово-серый
ACCENT_COLOR = (230, 140, 170)      # Нежно-розовый акцент
INPUT_BG = (255, 245, 248)          # Светлый фон поля ввода
INPUT_BORDER_ACTIVE = (200, 120, 150)  # Цвет рамки при фокусе
INPUT_BORDER_INACTIVE = (225, 205, 215) # Цвет рамки без фокуса
CURSOR_COLOR = (180, 100, 130)      # Цвет курсора
LINE_COLOR = (225, 205, 215)        # Цвет линий игрового поля
CIRCLE_COLOR = (230, 140, 170)      # Цвет ноликов
CROSS_COLOR = (110, 170, 230)       # Цвет крестиков
BUTTON_COLOR = (235, 190, 205)
BUTTON_HOVER = (215, 165, 180)
MESSAGE_BG = (255, 245, 248, 220)   # Полупрозрачный фон сообщений
SUCCESS_COLOR = (100, 180, 100)     # Цвет для сообщений об успехе
LOADING_COLOR = (150, 120, 170)     # Цвет для индикатора загрузки

# === Состояния приложения ===
STATE_AUTH = 0
STATE_GAME = 1
STATE_LOADING = 2
current_state = STATE_AUTH

# === Данные пользователя ===
user_data = {
    "telegram_username": "",
    "chat_id": None,
    "bot_token": "YOUR_TOKEN",  
    "game_stats": {"wins": 0, "losses": 0, "draws": 0}
}

# === Загрузка шрифтов РАЗДЕЛЬНО для эмодзи и текста ===
def load_fonts():
    """Загружает ОТДЕЛЬНЫЕ шрифты для эмодзи и обычного текста"""
    
    # Сначала пробуем загрузить шрифты для эмодзи
    try:
        # Специализированные шрифты для эмодзи
        emoji_fonts = [
            "Segoe UI Emoji",      # Windows
            "Apple Color Emoji",   # macOS
            "Noto Color Emoji",    # Linux
            "Twemoji Mozilla",     # Firefox
            "sans-serif"           # fallback
        ]
        emoji_font_name = ",".join(emoji_fonts)
        emoji_title_font = pygame.font.SysFont(emoji_font_name, 48, bold=True)
        emoji_small_font = pygame.font.SysFont(emoji_font_name, 28)
        emoji_tiny_font = pygame.font.SysFont(emoji_font_name, 20)
        emoji_game_font = pygame.font.SysFont(emoji_font_name, 36, bold=True)
        emoji_loading_font = pygame.font.SysFont(emoji_font_name, 24)
        
        emoji_fonts_loaded = True
    except:
        # Если не удалось загрузить шрифты для эмодзи - используем запасные символы
        emoji_fonts_loaded = False
        emoji_title_font = pygame.font.Font(None, 48)
        emoji_small_font = pygame.font.Font(None, 28)
        emoji_tiny_font = pygame.font.Font(None, 20)
        emoji_game_font = pygame.font.Font(None, 36)
        emoji_loading_font = pygame.font.Font(None, 24)
    
    # Теперь загружаем шрифты для обычного текста
    try:
        # Универсальные шрифты для текста
        text_fonts = [
            "SF Pro Display",      # macOS
            "Segoe UI",            # Windows
            "Helvetica Neue",      # macOS/Linux
            "Noto Sans",           # Linux
            "Arial",               # fallback
            "sans-serif"           # fallback
        ]
        text_font_name = ",".join(text_fonts)
        title_font = pygame.font.SysFont(text_font_name, 48, bold=True)
        input_font = pygame.font.SysFont(text_font_name, 32)
        small_font = pygame.font.SysFont(text_font_name, 28)
        tiny_font = pygame.font.SysFont(text_font_name, 20)
        game_font = pygame.font.SysFont(text_font_name, 36, bold=True)
        loading_font = pygame.font.SysFont(text_font_name, 24)
    except:
        # Если не удалось - используем стандартные шрифты
        title_font = pygame.font.Font(None, 48)
        input_font = pygame.font.Font(None, 32)
        small_font = pygame.font.Font(None, 28)
        tiny_font = pygame.font.Font(None, 20)
        game_font = pygame.font.Font(None, 36)
        loading_font = pygame.font.Font(None, 24)
    
    # Возвращаем ОБА набора шрифтов
    return {
        'emoji': {
            'title': emoji_title_font,
            'small': emoji_small_font,
            'tiny': emoji_tiny_font,
            'game': emoji_game_font,
            'loading': emoji_loading_font,
            'loaded': emoji_fonts_loaded
        },
        'text': {
            'title': title_font,
            'input': input_font,
            'small': small_font,
            'tiny': tiny_font,
            'game': game_font,
            'loading': loading_font
        }
    }

# Загружаем шрифты
fonts = load_fonts()

screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("🌸 Крестики-Нолики")

# === Класс поля ввода ===
class InputField:
    def __init__(self, x, y, width, height, placeholder=""):
        self.rect = pygame.Rect(x, y, width, height)
        self.text = ""
        self.placeholder = placeholder
        self.active = False
        self.cursor_visible = True
        self.cursor_timer = 0
        self.cursor_pos = 0
        self.blink_speed = 500  # мс
        self.max_length = 32
        
    def handle_event(self, event):
        if event.type == pygame.MOUSEBUTTONDOWN:
            # Проверка клика по полю
            self.active = self.rect.collidepoint(event.pos)
        
        if not self.active:
            return
        
        if event.type == pygame.KEYDOWN:
            # Backspace
            if event.key == pygame.K_BACKSPACE:
                if self.cursor_pos > 0:
                    self.text = self.text[:self.cursor_pos-1] + self.text[self.cursor_pos:]
                    self.cursor_pos = max(0, self.cursor_pos - 1)
            
            # Delete
            elif event.key == pygame.K_DELETE:
                if self.cursor_pos < len(self.text):
                    self.text = self.text[:self.cursor_pos] + self.text[self.cursor_pos+1:]
            
            # Стрелки влево/вправо
            elif event.key == pygame.K_LEFT:
                self.cursor_pos = max(0, self.cursor_pos - 1)
            elif event.key == pygame.K_RIGHT:
                self.cursor_pos = min(len(self.text), self.cursor_pos + 1)
            
            # Home/End
            elif event.key == pygame.K_HOME:
                self.cursor_pos = 0
            elif event.key == pygame.K_END:
                self.cursor_pos = len(self.text)
            
            # Ввод символов
            elif event.unicode and len(self.text) < self.max_length:
                # Разрешаем только допустимые символы для Telegram username
                if re.match(r'^[a-zA-Z0-9_\.]$', event.unicode):
                    self.text = self.text[:self.cursor_pos] + event.unicode + self.text[self.cursor_pos:]
                    self.cursor_pos += 1
    
    def update(self, dt):
        """Обновление состояния курсора"""
        self.cursor_timer += dt
        if self.cursor_timer >= self.blink_speed:
            self.cursor_visible = not self.cursor_visible
            self.cursor_timer = 0
    
    def draw(self, surface):
        """Отрисовка поля ввода"""
        # Фон поля
        pygame.draw.rect(surface, INPUT_BG, self.rect, border_radius=15)
        
        # Рамка (активное/неактивное состояние)
        border_color = INPUT_BORDER_ACTIVE if self.active else INPUT_BORDER_INACTIVE
        pygame.draw.rect(surface, border_color, self.rect, 3, border_radius=15)
        
        # Текст
        if self.text or not self.placeholder:
            text_surf = fonts['text']['input'].render(self.text, True, TEXT_COLOR)
            # Автоматическая прокрутка текста
            text_x = self.rect.x + 15
            if text_surf.get_width() > self.rect.width - 40:
                offset = min(0, self.rect.width - 40 - text_surf.get_width())
                text_x += offset
            surface.blit(text_surf, (text_x, self.rect.y + (self.rect.height - text_surf.get_height()) // 2))
        else:
            # Placeholder
            placeholder_surf = fonts['text']['input'].render(self.placeholder, True, (180, 160, 170))
            surface.blit(placeholder_surf, 
                        (self.rect.x + 15, 
                         self.rect.y + (self.rect.height - placeholder_surf.get_height()) // 2))
        
        # Курсор
        if self.active and self.cursor_visible:
            cursor_x = self.rect.x + 15
            if self.text:
                # Позиция курсора относительно текста
                cursor_text = self.text[:self.cursor_pos]
                cursor_width = fonts['text']['input'].size(cursor_text)[0]
                cursor_x += cursor_width
            
            # Ограничение курсора в пределах поля
            cursor_x = min(cursor_x, self.rect.right - 15)
            
            cursor_y = self.rect.y + 10
            cursor_height = self.rect.height - 20
            pygame.draw.line(surface, CURSOR_COLOR, 
                           (cursor_x, cursor_y), 
                           (cursor_x, cursor_y + cursor_height), 2)

# === Символы для эмодзи (альтернатива для кроссплатформенности) ===
EMOJI_MAP = {
    "sparkles": "✨",
    "flower": "🌸", 
    "dizzy": "💫",
    "tada": "🎉",
    "gift": "🎁",
    "handshake": "🤝",
    "heart": "♡",
    "crown": "👑",
    "star": "⭐"
}

def get_emoji_symbol(name):
    """Возвращает символ эмодзи или текстовую замену"""
    if fonts['emoji']['loaded']:
        return EMOJI_MAP.get(name, "")
    else:
        # Текстовые замены для систем без поддержки эмодзи
        replacements = {
            "sparkles": "*",
            "flower": "@",
            "dizzy": "~",
            "tada": "!",
            "gift": "$",
            "handshake": "=",
            "heart": "<3",
            "crown": "^",
            "star": "*"
        }
        return replacements.get(name, "")

def draw_emoji(surface, emoji_name, position, size=28, color=TEXT_COLOR):
    """Отдельная функция для отрисовки эмодзи"""
    symbol = get_emoji_symbol(emoji_name)
    if not symbol:
        return
    
    # Выбираем подходящий шрифт для размера
    if size > 40:
        font = fonts['emoji']['title']
    elif size > 24:
        font = fonts['emoji']['small']
    else:
        font = fonts['emoji']['tiny']
    
    # Рендерим эмодзи
    emoji_surf = font.render(symbol, True, color)
    surface.blit(emoji_surf, position)
    return emoji_surf.get_rect(topleft=position)

def draw_text(surface, text, position, font_key='small', color=TEXT_COLOR, center=False):
    """Отдельная функция для отрисовки текста"""
    font = fonts['text'][font_key]
    text_surf = font.render(text, True, color)
    
    if center:
        text_rect = text_surf.get_rect(center=position)
        surface.blit(text_surf, text_rect)
        return text_rect
    else:
        surface.blit(text_surf, position)
        return text_surf.get_rect(topleft=position)

def draw_text_with_emoji(surface, text_parts, position, line_height=30):
    """
    Отрисовка текста с эмодзи как отдельных элементов
    text_parts: список кортежей (тип, содержимое)
        тип: 'text' или 'emoji'
        содержимое: текст или имя эмодзи
    """
    x, y = position
    max_width = 0
    current_y = y
    
    for part_type, content in text_parts:
        if part_type == 'text':
            text_surf = fonts['text']['small'].render(content, True, TEXT_COLOR)
            surface.blit(text_surf, (x, current_y))
            x += text_surf.get_width() + 5
            max_width = max(max_width, x - position[0])
        elif part_type == 'emoji':
            symbol = get_emoji_symbol(content)
            if symbol:
                emoji_surf = fonts['emoji']['small'].render(symbol, True, ACCENT_COLOR)
                surface.blit(emoji_surf, (x, current_y - 5))  # Смещение для выравнивания
                x += emoji_surf.get_width() + 5
                max_width = max(max_width, x - position[0])
        
        # Если строка слишком длинная - переносим
        if x - position[0] > WIDTH - 100:
            x = position[0]
            current_y += line_height
    
    return pygame.Rect(position[0], position[1], max_width, current_y - position[1] + line_height)

# === Функции Telegram ===
async def get_chat_id_by_username(username, bot_token):
    """Получает chat_id пользователя через Telegram Bot API"""
    try:
        bot = Bot(token=bot_token)
        updates = await bot.get_updates(limit=100, timeout=30)
        
        for update in updates:
            if update.message and update.message.from_user:
                user = update.message.from_user
                if user.username and user.username.lower() == username.lower():
                    return user.id
        return None
    except Exception as e:
        print(f"Ошибка получения chat_id: {e}")
        return None

async def send_telegram_start_button(chat_id, bot_token):
    """Отправляет сообщение с кнопкой /start"""
    try:
        bot = Bot(token=bot_token)
        
        # Создаем кнопку /start
        keyboard = [[InlineKeyboardButton("✨ Начать игру", callback_data='start_game')]]
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        # Отправляем сообщение с кнопкой
        await bot.send_message(
            chat_id=chat_id,
            text="🌸 *Привет!* Я бот для игры в крестики-нолики.\n\n"
                 "Нажми кнопку ниже, чтобы начать игру и получить свой подарок при победе!",
            reply_markup=reply_markup,
            parse_mode="Markdown"
        )
        return True
    except Exception as e:
        print(f"Ошибка отправки кнопки /start: {e}")
        return False

async def send_telegram_message(chat_id, bot_token, text, with_start_button=False):
    """Отправляет сообщение в Telegram с опциональной кнопкой /start"""
    try:
        bot = Bot(token=bot_token)
        
        if with_start_button:
            # Создаем кнопку /start
            keyboard = [[InlineKeyboardButton("✨ Сыграть ещё", callback_data='play_again')]]
            reply_markup = InlineKeyboardMarkup(keyboard)
            await bot.send_message(
                chat_id=chat_id,
                text=text,
                reply_markup=reply_markup,
                parse_mode="Markdown"
            )
        else:
            await bot.send_message(
                chat_id=chat_id,
                text=text,
                parse_mode="Markdown"
            )
        return True
    except TelegramError as e:
        print(f"Ошибка Telegram: {e}")
        return False

# === Генерация промокода ===
def generate_promo():
    chars = string.ascii_uppercase.replace('O', '').replace('I', '') + string.digits.replace('0', '')
    return ''.join(random.choices(chars, k=5))

# === Окно авторизации ===
def draw_auth_screen(input_field, error_message="", success_message=""):
    screen.fill(BG_COLOR)
    
    # Заголовок с эмодзи и текстом как ОТДЕЛЬНЫЕ элементы
    title_x = WIDTH//2
    title_y = 80
    
    # Сначала рисуем эмодзи
    flower_rect = draw_emoji(screen, "flower", (title_x - 260, title_y - 10 ), size=48, color=ACCENT_COLOR)
    
    # Затем рисуем текст справа от эмодзи
    draw_text(screen, "Привяжи Telegram", (flower_rect.right + 10, title_y - 10), 
             font_key='title', color=ACCENT_COLOR)
    
    # Подзаголовок
    draw_text(screen, "Введите свой @username из Telegram", (WIDTH//2, 150), 
             font_key='small', color=TEXT_COLOR, center=True)
    
    # Поле ввода (уже отрисовано в основном цикле)
    
    # Кнопка "Подтвердить"
    btn_rect = pygame.Rect(WIDTH//2 - 120, 380, 240, 60)
    pygame.draw.rect(screen, ACCENT_COLOR, btn_rect, border_radius=20)
    draw_text(screen, "Подтвердить", btn_rect.center, 
             font_key='small', color=(255, 255, 255), center=True)
    
    # Сообщения
    y_offset = 480
    if error_message:
        draw_text(screen, error_message, (WIDTH//2, y_offset), 
                 font_key='small', color=(220, 80, 80), center=True)
        y_offset += 40
    elif success_message:
        draw_text(screen, success_message, (WIDTH//2, y_offset), 
                 font_key='small', color=SUCCESS_COLOR, center=True)
        y_offset += 40
    
    # Инструкция с раздельными эмодзи и текстом
    instruction_parts = [
        [('emoji', 'flower'), ('text', ' Запустите бота в Telegram: @YourGameBot')],
        [('emoji', 'sparkles'), ('text', ' Нажмите «Start»')],
        [('emoji', 'gift'), ('text', ' Введите ваш username ниже (без символа @)')]
    ]
    
    for i, parts in enumerate(instruction_parts):
        draw_text_with_emoji(screen, parts, (WIDTH//2 - 250, y_offset + i*40))
    
    # Декоративные элементы
    for i in range(8):
        x = random.randint(0, WIDTH)
        y = random.randint(0, HEIGHT//3)
        size = random.randint(2, 6)
        alpha = random.randint(40, 90)
        pygame.draw.circle(screen, (ACCENT_COLOR[0], ACCENT_COLOR[1], ACCENT_COLOR[2], alpha), (x, y), size)

# === Экран загрузки ===
def draw_loading_screen(message="Подключение к Telegram..."):
    screen.fill(BG_COLOR)
    
    # Заголовок с эмодзи и текстом
    title_x = WIDTH//2
    title_y = HEIGHT//3 - 50
    
    # Эмодзи цветок
    flower_rect = draw_emoji(screen, "flower", (title_x - 160, title_y - 15), size=48, color=ACCENT_COLOR)
    
    # Текст заголовка
    draw_text(screen, "Подождите", (flower_rect.right + 10, title_y), 
             font_key='title', color=ACCENT_COLOR)
    
    # Сообщение
    draw_text(screen, message, (WIDTH//2, HEIGHT//3 + 20), 
             font_key='small', color=TEXT_COLOR, center=True)
    
    # Индикатор загрузки (анимированный)
    loading_size = 60
    loading_x = WIDTH//2 - loading_size//2
    loading_y = HEIGHT//2
    
    # Анимация точек
    dots = int(pygame.time.get_ticks() / 2400) % 4
    dot_text = fonts['text']['small'].render("." * dots, True, ACCENT_COLOR)
    screen.blit(dot_text, (WIDTH//2 - dot_text.get_width()//2, HEIGHT//2 + 50))
    
    # Кружок загрузки
    angle = pygame.time.get_ticks() / 50 % 360
    for i in range(12):
        alpha = 255 - abs(i - (angle / 30 % 12)) * 25
        if alpha < 50:
            alpha = 50
        color = (LOADING_COLOR[0], LOADING_COLOR[1], LOADING_COLOR[2], alpha)
        circle_surf = pygame.Surface((loading_size, loading_size), pygame.SRCALPHA)
        pygame.draw.circle(circle_surf, color, (loading_size//2, loading_size//2), 8, 0)
        rotated = pygame.transform.rotate(circle_surf, -(i * 30 + angle))
        screen.blit(rotated, (loading_x, loading_y))

# === Игровая логика ===
class TicTacToeGame:
    def __init__(self):
        self.BOARD_SIZE = 3
        self.CELL_SIZE = WIDTH // self.BOARD_SIZE
        self.LINE_WIDTH = 8
        self.CIRCLE_WIDTH = 12
        self.CROSS_WIDTH = 16
        # УВЕЛИЧЕНА СКОРОСТЬ АНИМАЦИИ
        self.ANIM_SPEED = 0.4  # Значение от 0.1 до 1.0
        self.SPACE = self.CELL_SIZE // 4
        
        self.reset_game()
    
    def reset_game(self):
        self.board = [["" for _ in range(self.BOARD_SIZE)] for _ in range(self.BOARD_SIZE)]
        self.animations = [[0 for _ in range(self.BOARD_SIZE)] for _ in range(self.BOARD_SIZE)]
        self.player = "X"
        self.game_over = False
        self.result_message = ""
        self.promo_code = ""
    
    def check_winner(self):
        for i in range(self.BOARD_SIZE):
            if self.board[i][0] == self.board[i][1] == self.board[i][2] != "":
                return self.board[i][0]
            if self.board[0][i] == self.board[1][i] == self.board[2][i] != "":
                return self.board[0][i]
        if self.board[0][0] == self.board[1][1] == self.board[2][2] != "":
            return self.board[0][0]
        if self.board[0][2] == self.board[1][1] == self.board[2][0] != "":
            return self.board[0][2]
        return None
    
    def is_board_full(self):
        return all(self.board[i][j] != "" for i in range(self.BOARD_SIZE) for j in range(self.BOARD_SIZE))
    
    def computer_move(self):
        empty_cells = [(i, j) for i in range(self.BOARD_SIZE) for j in range(self.BOARD_SIZE) if self.board[i][j] == ""]
        if empty_cells:
            i, j = random.choice(empty_cells)
            self.board[i][j] = "O"
            self.animations[i][j] = 0
    
    def update(self, dt):
        for i in range(self.BOARD_SIZE):
            for j in range(self.BOARD_SIZE):
                if self.animations[i][j] < 1.0:
                    # УСКОРЕННОЕ ОБНОВЛЕНИЕ АНИМАЦИИ
                    self.animations[i][j] = min(1.0, self.animations[i][j] + self.ANIM_SPEED)
    
    def draw_background(self):
        screen.fill(BG_COLOR)
        # Едва заметные точки-украшения
        for x in range(25, WIDTH, 45):
            for y in range(25, HEIGHT - 100, 45):
                alpha = 30 + int(20 * math.sin(pygame.time.get_ticks() / 1500 + x * y))
                dot_color = (240, 210, 225, alpha)
                dot_surf = pygame.Surface((8, 8), pygame.SRCALPHA)
                pygame.draw.circle(dot_surf, dot_color, (4, 4), 2)
                screen.blit(dot_surf, (x, y))
    
    def draw_board(self):
        # Основной фон доски
        board_surf = pygame.Surface((WIDTH - 20, WIDTH - 20), pygame.SRCALPHA)
        pygame.draw.rect(board_surf, (250, 240, 245, 200), board_surf.get_rect(), border_radius=16)
        screen.blit(board_surf, (10, 10))
        
        # Сетка
        for i in range(1, self.BOARD_SIZE):
            # Горизонтальные линии
            pygame.draw.line(screen, LINE_COLOR, 
                           (15, i * self.CELL_SIZE + 5), 
                           (WIDTH - 15, i * self.CELL_SIZE + 5), self.LINE_WIDTH // 2)
            
            # Вертикальные линии
            pygame.draw.line(screen, LINE_COLOR, 
                           (i * self.CELL_SIZE + 5, 15), 
                           (i * self.CELL_SIZE + 5, WIDTH - 15), self.LINE_WIDTH // 2)
    
    def draw_figures(self):
        for row in range(self.BOARD_SIZE):
            for col in range(self.BOARD_SIZE):
                x = col * self.CELL_SIZE + self.CELL_SIZE // 2
                y = row * self.CELL_SIZE + self.CELL_SIZE // 2
                progress = self.animations[row][col]
                
                if self.board[row][col] == "X":
                    size = int((self.SPACE * 0.8) * progress)
                    # Тени для объёма
                    pygame.draw.line(screen, (80, 140, 200),
                                   (x - size, y - size), (x + size, y + size), self.CROSS_WIDTH + 2)
                    pygame.draw.line(screen, (80, 140, 200),
                                   (x + size, y - size), (x - size, y + size), self.CROSS_WIDTH + 2)
                    # Основные линии
                    pygame.draw.line(screen, CROSS_COLOR,
                                   (x - size, y - size), (x + size, y + size), self.CROSS_WIDTH)
                    pygame.draw.line(screen, CROSS_COLOR,
                                   (x + size, y - size), (x - size, y + size), self.CROSS_WIDTH)
                    # Закругленные концы
                    for pos in [(x-size, y-size), (x+size, y+size), (x+size, y-size), (x-size, y+size)]:
                        pygame.draw.circle(screen, CROSS_COLOR, pos, self.CROSS_WIDTH//2 + 1)
                
                elif self.board[row][col] == "O":
                    radius = int((self.SPACE * 0.8) * progress)
                    # Тень для объёма
                    pygame.draw.circle(screen, (200, 110, 130), (x, y), radius + 2, self.CIRCLE_WIDTH + 1)
                    # Основной круг
                    pygame.draw.circle(screen, CIRCLE_COLOR, (x, y), radius, self.CIRCLE_WIDTH)
                    # Внутренняя подсветка
                    if progress > 0.7:
                        inner_radius = int(radius * 0.6)
                        pygame.draw.circle(screen, (255, 240, 245), (x, y), inner_radius)
    
    def draw_message(self):
        if not self.result_message:
            return
        
        # Полупрозрачный фон
        msg_height = 120
        msg_surf = pygame.Surface((WIDTH - 30, msg_height), pygame.SRCALPHA)
        pygame.draw.rect(msg_surf, MESSAGE_BG, msg_surf.get_rect(), border_radius=20)
        screen.blit(msg_surf, (15, WIDTH + 20))
        
        # Определяем эмодзи в зависимости от результата
        if "победила" in self.result_message:
            emoji_name = "tada"
            color = (160, 80, 120)
        elif "Не повезло" in self.result_message:
            emoji_name = "dizzy"
            color = (100, 100, 150)
        else:
            emoji_name = "handshake"
            color = (100, 130, 100)
        
        # Позиционирование: эмодзи слева, текст справа
        emoji_x = 30
        emoji_y = WIDTH + 40
        text_x = emoji_x + 60
        text_y = WIDTH + 45
        
        # Рисуем эмодзи
        draw_emoji(screen, emoji_name, (emoji_x, emoji_y), size=36, color=color)
        
        # Рисуем текст результата
        draw_text(screen, self.result_message, (text_x, text_y), 
                 font_key='game', color=color)
        
        # Пульсирующий эффект для промокода
        if self.promo_code:
            pulse = 1 + 0.05 * math.sin(pygame.time.get_ticks() / 100)
            gift_x = WIDTH // 2 - 100
            gift_y = WIDTH + 80
            
            # Эмодзи подарка
            draw_emoji(screen, "gift", (gift_x, gift_y - 5), size=20, color=(180, 80, 120))
            
            # Текст промокода справа от эмодзи
            promo_text = f"Твой подарок: {self.promo_code}"
            promo_surf = fonts['text']['tiny'].render(promo_text, True, (180, 80, 120))
            
            # Применяем пульсацию к позиции
            promo_x = gift_x + 30 + (1 - pulse) * 10
            screen.blit(promo_surf, (promo_x, gift_y))
    
    def draw_retry_button(self, hover=False):
        if not (self.game_over and "Не повезло" in self.result_message):
            return None
        
        btn_width, btn_height = 240, 60
        btn_x = WIDTH // 2 - btn_width // 2
        btn_y = HEIGHT - 85
        
        # Плавное увеличение при наведении
        scale = 1.03 if hover else 1.0
        scaled_width = int(btn_width * scale)
        scaled_height = int(btn_height * scale)
        
        # Фон кнопки
        btn_surf = pygame.Surface((scaled_width, scaled_height), pygame.SRCALPHA)
        pygame.draw.rect(btn_surf, BUTTON_HOVER if hover else BUTTON_COLOR, 
                        btn_surf.get_rect(), border_radius=18)
        
        screen.blit(btn_surf, (btn_x - (scaled_width - btn_width) // 2, 
                              btn_y - (scaled_height - btn_height) // 2))
        
        # Эмодзи и текст как ОТДЕЛЬНЫЕ элементы
        emoji_x = btn_x + 20
        emoji_y = btn_y + (btn_height - 24) // 2
        text_x = emoji_x + 30
        text_y = btn_y + (btn_height - 28) // 2
        
        # Искра перед текстом
        draw_emoji(screen, "sparkles", (emoji_x, emoji_y), size=24, color=TEXT_COLOR)
        
        # Текст кнопки
        draw_text(screen, "Сыграть ещё", (text_x, text_y), 
                 font_key='small', color=TEXT_COLOR)
        
        # Возвращаем прямоугольник кнопки для проверки кликов
        return pygame.Rect(btn_x, btn_y, btn_width, btn_height)
    
    def draw_watermark(self):
        # "made with" текст
        text_surf = fonts['text']['tiny'].render("made with ", True, (210, 190, 200))
        text_rect = text_surf.get_rect(bottomright=(WIDTH - 15, HEIGHT - 15))
        screen.blit(text_surf, text_rect)
        
        # Сердечко справа от текста
        heart_x = text_rect.right + 5
        heart_y = text_rect.top - 2
        draw_emoji(screen, "heart", (heart_x, heart_y), size=16, color=(210, 190, 200))
    
    def draw_back_button(self, hover=False):
        btn_rect = pygame.Rect(20, 20, 140, 40)
        pygame.draw.rect(screen, BUTTON_HOVER if hover else BUTTON_COLOR, btn_rect, border_radius=10)
        
        # Эмодзи цветка
        flower_x = btn_rect.x + 10
        flower_y = btn_rect.y + (btn_rect.height - 24) // 2
        draw_emoji(screen, "flower", (flower_x, flower_y), size=24, color=TEXT_COLOR)
        
        # Текст "Меню" справа от эмодзи
        text_x = flower_x + 30
        text_y = btn_rect.y + (btn_rect.height - 35) // 2
        draw_text(screen, "Меню", (text_x, text_y), 
                 font_key='small', color=TEXT_COLOR)
        
        return btn_rect

# === Основная функция ===
async def main():
    global current_state
    
    # Создание поля ввода для авторизации
    input_field = InputField(WIDTH//2 - 200, 250, 400, 60, "@ваш_username")
    
    # Предзаполнение, если есть сохраненные данные
    if user_data.get("telegram_username"):
        input_field.text = user_data["telegram_username"]
        input_field.cursor_pos = len(input_field.text)
    
    # Создание игрового объекта
    game = TicTacToeGame()
    
    error_message = ""
    success_message = ""
    last_frame_time = pygame.time.get_ticks()
    
    # Кнопка подтверждения для авторизации
    auth_btn_rect = pygame.Rect(WIDTH//2 - 120, 380, 240, 60)
    
    # Флаг для отслеживания отправки кнопки /start
    start_button_sent = False
    
    running = True
    while running:
        current_time = pygame.time.get_ticks()
        dt = (current_time - last_frame_time) / 1000.0  # В секундах
        last_frame_time = current_time
        
        # Обновление курсора в поле ввода
        if current_state == STATE_AUTH:
            input_field.update(current_time - last_frame_time)
        
        # Обновление анимаций в игре
        if current_state == STATE_GAME:
            game.update(dt)
        
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                sys.exit()
            
            if current_state == STATE_AUTH:
                # Обработка событий поля ввода
                input_field.handle_event(event)
                
                # Обработка кнопки авторизации
                if event.type == pygame.MOUSEBUTTONDOWN:
                    mouse_pos = event.pos
                    
                    # Клик по кнопке подтверждения
                    if auth_btn_rect.collidepoint(mouse_pos) and input_field.text.strip():
                        username = input_field.text.strip()
                        
                        # Убираем @ если пользователь его ввел
                        username = username.lstrip('@')
                        
                        # Валидация username
                        if not re.match(r'^[a-zA-Z0-9_\.]{5,32}$', username):
                            error_message = "❌ Неверный формат username. Только буквы, цифры, _ и ."
                            success_message = ""
                            continue
                        
                        # Переход в состояние загрузки
                        current_state = STATE_LOADING
                        loading_message = "Подключение к Telegram..."
                        
                        # Попытка получить chat_id
                        try:
                            chat_id = await get_chat_id_by_username(username, user_data["bot_token"])
                            
                            if chat_id:
                                user_data["telegram_username"] = username
                                user_data["chat_id"] = chat_id
                                
                                # Отправка кнопки /start после успешной привязки
                                if await send_telegram_start_button(chat_id, user_data["bot_token"]):
                                    success_message = "✅ Аккаунт успешно привязан! Кнопка /start отправлена в Telegram."
                                    start_button_sent = True
                                else:
                                    success_message = "✅ Аккаунт успешно привязан! (Не удалось отправить кнопку /start)"
                                
                                error_message = ""
                                # Автоматический переход в игру через 2 секунды
                                pygame.time.set_timer(pygame.USEREVENT, 2000)
                            else:
                                error_message = "❌ Пользователь не найден. Напишите боту в Telegram!"
                                success_message = ""
                                current_state = STATE_AUTH
                        except Exception as e:
                            error_message = f"❌ Ошибка подключения: {str(e)}"
                            success_message = ""
                            current_state = STATE_AUTH
                    
                    # Если кликнули вне поля ввода - снимаем фокус
                    elif not input_field.rect.collidepoint(mouse_pos):
                        input_field.active = False
                
                # Обработка Enter
                if event.type == pygame.KEYDOWN:
                    if event.key == pygame.K_RETURN and input_field.text.strip():
                        username = input_field.text.strip().lstrip('@')
                        if re.match(r'^[a-zA-Z0-9_\.]{5,32}$', username):
                            # Переход в состояние загрузки
                            current_state = STATE_LOADING
                            loading_message = "Подключение к Telegram..."
                            
                            try:
                                chat_id = await get_chat_id_by_username(username, user_data["bot_token"])
                                if chat_id:
                                    user_data["telegram_username"] = username
                                    user_data["chat_id"] = chat_id
                                    
                                    # Отправка кнопки /start
                                    if await send_telegram_start_button(chat_id, user_data["bot_token"]):
                                        success_message = "✅ Аккаунт успешно привязан! Кнопка /start отправлена в Telegram."
                                        start_button_sent = True
                                    else:
                                        success_message = "✅ Аккаунт успешно привязан! (Не удалось отправить кнопку /start)"
                                    
                                    error_message = ""
                                    pygame.time.set_timer(pygame.USEREVENT, 2000)
                                else:
                                    error_message = "❌ Пользователь не найден. Напишите боту в Telegram!"
                                    success_message = ""
                                    current_state = STATE_AUTH
                            except Exception as e:
                                error_message = f"❌ Ошибка подключения: {str(e)}"
                                success_message = ""
                                current_state = STATE_AUTH
            
            elif current_state == STATE_GAME:
                # Обработка событий игры
                if event.type == pygame.MOUSEBUTTONDOWN:
                    mouse_x, mouse_y = event.pos
                    
                    # Проверка кнопки "Назад в меню"
                    back_btn = game.draw_back_button()
                    if back_btn.collidepoint(mouse_x, mouse_y):
                        current_state = STATE_AUTH
                        continue
                    
                    # Если игра окончена и есть кнопка "Сыграть ещё"
                    if game.game_over and "Не повезло" in game.result_message:
                        retry_btn = game.draw_retry_button(False)  # Получаем прямоугольник кнопки
                        if retry_btn and retry_btn.collidepoint(mouse_x, mouse_y):
                            game.reset_game()
                            continue
                    
                    # Ход игрока
                    if not game.game_over:
                        clicked_row = mouse_y // game.CELL_SIZE
                        clicked_col = mouse_x // game.CELL_SIZE
                        
                        if 0 <= clicked_row < game.BOARD_SIZE and 0 <= clicked_col < game.BOARD_SIZE:
                            if game.board[clicked_row][clicked_col] == "":
                                # Ход игрока
                                game.board[clicked_row][clicked_col] = "X"
                                game.animations[clicked_row][clicked_col] = 0
                                
                                winner = game.check_winner()
                                if winner == "X":
                                    game.promo_code = generate_promo()
                                    game.result_message = "Ты победила!"
                                    user_data["game_stats"]["wins"] += 1
                                    # Отправка сообщения с промокодом и кнопкой /start
                                    await send_telegram_message(
                                        user_data["chat_id"],
                                        user_data["bot_token"],
                                        f"🎉 *Поздравляю!* Ты победила в игре!\n\n"
                                        f"🎁 Твой подарок: `{game.promo_code}`\n\n"
                                        f"Этот код можно использовать для скидки в нашем магазине.",
                                        with_start_button=True
                                    )
                                    game.game_over = True
                                elif game.is_board_full():
                                    game.result_message = "Ничья — мы в одном ритме!"
                                    user_data["game_stats"]["draws"] += 1
                                    game.game_over = True
                                else:
                                    # Ход компьютера (с небольшой задержкой для эффекта)
                                    pygame.time.delay(300)
                                    game.computer_move()
                                    winner = game.check_winner()
                                    if winner == "O":
                                        game.result_message = "Не повезло... Но ты прекрасна!"
                                        user_data["game_stats"]["losses"] += 1
                                        # Отправка сообщения с кнопкой /start при проигрыше
                                        await send_telegram_message(
                                            user_data["chat_id"],
                                            user_data["bot_token"],
                                            f"💫 *Не повезло в этот раз...*\n\n"
                                            f"Но ты всегда можешь попробовать снова! Нажми кнопку ниже, чтобы сыграть ещё.",
                                            with_start_button=True
                                        )
                                        game.game_over = True
                                    elif game.is_board_full():
                                        game.result_message = "Ничья — мы в одном ритме!"
                                        user_data["game_stats"]["draws"] += 1
                                        game.game_over = True
            
            # Автоматический переход в игру после успешной авторизации
            if event.type == pygame.USEREVENT:
                if success_message and current_state == STATE_LOADING:
                    current_state = STATE_GAME
                pygame.time.set_timer(pygame.USEREVENT, 0)  # Отключить таймер
        
        # Отрисовка интерфейса
        if current_state == STATE_AUTH:
            draw_auth_screen(input_field, error_message, success_message)
            input_field.draw(screen)
            
            # Подсветка кнопки при наведении
            mouse_pos = pygame.mouse.get_pos()
            btn_hover = auth_btn_rect.collidepoint(mouse_pos) and input_field.text.strip()
            btn_color = (210, 120, 150) if btn_hover else ACCENT_COLOR
            pygame.draw.rect(screen, btn_color, auth_btn_rect, border_radius=20)
            draw_text(screen, "Подтвердить", auth_btn_rect.center, 
                     font_key='small', color=(255, 255, 255), center=True)
        
        elif current_state == STATE_LOADING:
            draw_loading_screen(loading_message if 'loading_message' in locals() else "Подключение...")
        
        elif current_state == STATE_GAME:
            game.draw_background()
            game.draw_board()
            game.draw_figures()
            game.draw_message()
            
            # Кнопка "Сыграть ещё" при проигрыше
            mouse_pos = pygame.mouse.get_pos()
            retry_btn_rect = None
            if game.game_over and "Не повезло" in game.result_message:
                # Получаем прямоугольник кнопки для проверки наведения
                retry_btn_rect = game.draw_retry_button(False)
                if retry_btn_rect and retry_btn_rect.collidepoint(mouse_pos):
                    game.draw_retry_button(True)  # Перерисовываем с эффектом наведения
            
            # Кнопка "Назад в меню"
            back_hover = False
            back_btn_rect = pygame.Rect(20, 20, 140, 40)
            if back_btn_rect.collidepoint(mouse_pos):
                back_hover = True
            game.draw_back_button(back_hover)
            
            game.draw_watermark()
        
        pygame.display.flip()
        clock.tick(60)

if __name__ == "__main__":
    asyncio.run(main())
