# frozen_string_literal: true

require 'bundler/setup'
require 'chess_engine_rb'

# A simple CLI for playing chess using the engine
class SimpleChessCli
  def initialize
    @engine = ChessEngine::Engine.new(default_parser: ChessEngine::Parsers::ERANParser)
    @engine.add_listener(self)
    @captured_pieces = { white: [], black: [] }
    @last_update = nil
    @last_error = nil
  end

  def start
    Console.welcome_screen
    select_session
    play_turn until game_over?
    end_game
  end

  # This method must be implemented by engine listeners,
  # and it demonstrates how a UI might utilize the event/listener model.
  def on_game_update(update)
    if update.failure?
      @last_error = update.error
    else
      @last_error = nil
      @last_update = update
      if (captured = update&.event&.captured)
        @captured_pieces[captured.piece.color] << captured.piece.type
      end
    end
  end

  private

  def select_session
    Console.session_selection_screen
    selection = Console.input('>>> ').strip
    if selection == ''
      @engine.new_game
    elsif valid_fen?(selection)
      @engine.from_fen(selection)
    else
      select_session
    end
  end

  def play_turn
    Console.game_screen(@last_update, @last_error, @captured_pieces)
    puts
    player_action
  end

  # Here is a good demonstration of the engine's merit.
  # The UI doesn't need to handle any game logic - it just passes it to the engine.
  def player_action
    inp = Console.input('      Enter move or command: ').downcase.strip
    case inp
    when 'do' then @engine.offer_draw
    when 'da' then @engine.accept_draw
    when 'dc' then @engine.claim_draw
    when 'r' then @engine.resign
    when 'h' then Console.help_screen
    when 'q' then @quit = true
    else @engine.play_turn(inp)
    end
  end

  def valid_fen?(str)
    begin
      ChessEngine::Position.from_fen(str)
    rescue ArgumentError
      return false
    end
    true
  end

  def game_over?
    @last_update.game_ended? || @quit
  end

  def end_game
    if @quit
      Console.quit_game_screen(@last_update)
    else
      Console.game_end_screen(@last_update)
    end
  end
end

# General and game-related IO
module Console # rubocop:disable Metrics/ModuleLength
  extend self

  # In chars
  WIDTH = 80
  HEIGHT = 35
  SQR_WIDTH = 7

  BLANK = (' ' * 7)
  PIECES = {
    black: { pawn: '♟', knight: '♞', bishop: '♝', rook: '♜', queen: '♛', king: '♚' },
    white: { pawn: '♙', knight: '♘', bishop: '♗', rook: '♖', queen: '♕', king: '♔' }
  }.freeze

  # Colors
  BG_LIGHT = "\e[48;5;180m"
  BG_DARK  = "\e[48;5;130m"
  COLOR_RESET = "\e[0m"
  FG_WHITE_PIECE = "\e[97m"
  FG_BLACK_PIECE = "\e[30m"

  FORMATTER = ChessEngine::Formatters::ERANLongFormatter

  def welcome_screen
    clear
    puts <<~HEREDOC
      ████████████████████████████████████████████████████████████████████████████████
      ██                                                                            ██
      ██                                                                            ██
      ██                                                                            ██
      ██                                                                            ██
      ██        ▐▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▌         ██
      ██        ▐/////////////////////////////////////////////////////////▌         ██
      ██        ▐/////////////////////////////////////////////////////////▌         ██
      ██        ▐///////█████████//█████//////////////////////////////////▌         ██
      ██        ▐//////███░░░░░███░░███///////////////////////////////////▌         ██
      ██        ▐/////███/////░░░//░███████////██████///█████///█████/////▌         ██
      ██        ▐////░███//////////░███░░███//███░░███/███░░///███░░//////▌         ██
      ██        ▐////░███//////////░███/░███/░███████/░░█████/░░█████/////▌         ██
      ██        ▐////░░███/////███/░███/░███/░███░░░///░░░░███/░░░░███////▌         ██
      ██        ▐/////░░█████████//████/█████░░██████//██████//██████/////▌         ██
      ██        ▐//////░░░░░░░░░//░░░░/░░░░░//░░░░░░//░░░░░░//░░░░░░//////▌         ██
      ██        ▐/////////////////////////////////////////////////////////▌         ██
      ██        ▐/////////////////////////////////////////////////////////▌         ██
      ██        ▐▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▌         ██
      ██           A simple Chess CLI                                               ██
      ██                                                                            ██
      ██                                                                            ██
      ██                                                                            ██
      ██                                                                            ██
      ██              <Fit your screen until the whole screen fits in>              ██
      ██                                                                            ██
      ██                                                                            ██
      ██                                                                            ██
      ██                          -------------------------                         ██
      ██                          Press [ENTER] to start...                         ██
      ██                                                                            ██
      ██                                                                            ██
      ██                                                                            ██
      ██                                                                            ██
      ████████████████████████████████████████████████████████████████████████████████
    HEREDOC
    gets
    help_screen
  end

  def help_screen
    clear
    puts <<~HEREDOC
      ================================================================================
      ============================= Chess CLI Instructions ==========================
      ================================================================================

      Either enter a chess move or one of the special commands.

      ------- Chess Moves (ERAN notation) -------------------------------------------
      - Regular moves: PIECE SQUARE-SQUARE
          - PIECE: piece name (full or letter)
          - SQUARE-SQUARE: origin and destination squares, e.g., d2-d4
          - Examples:
              - Pawn a2 to a4:      p a2-a4  or  pawn a2-a4
              - Knight b1 to c3:    n b1-c3  or  knight b1-c3
          - Captures: use 'x' instead of '-', e.g., q c3xc5
          - Promotions: append ->PIECE or >PIECE, e.g., p c7-c8 ->queen

      - Special moves:
          - Kingside castling:  ck  or  castling-kingside
          - Queenside castling: cq  or  castling-queenside
          - En passant:         ep  or  en-passant

      ------- Special Game Commands --------------------------------------------------
      - do : Offer draw
      - da : Accept draw
      - dc : Claim draw
      - r  : Resign
      - q  : Quit and display FEN
      - h  : Display these instructions again

      ================================================================================
      Press [ENTER] to continue...
      ================================================================================
    HEREDOC
    gets
  end

  def session_selection_screen
    clear
    puts <<~HEREDOC
      ================================================================================
      ================================== Game Setup ==================================
      ================================================================================

      Enter a FEN string to load an existing game.
      Leave empty and press <ENTER> to start a new game.

    HEREDOC
  end

  def game_screen(status, last_error, captured_pieces)
    clear
    print_status_bar(status)
    print_board(status.board)
    puts
    pcenter "Captured: #{captured_pieces_str(captured_pieces)}"
    pcenter special_moves_bar(status.game_query.legal_moves.to_a)
    puts
    pcenter error_message(last_error)
  end

  def quit_game_screen(status)
    end_screen('Game Quit', status.board)
    puts "Game ended by player quitting.\n\nFEN: #{status.position.to_fen}"
  end

  def game_end_screen(status)
    end_screen('Game Over', status.board)

    outcome = status.endgame_status
    winner  = outcome.winner
    cause   = outcome.cause

    draw_message = {
      agreement: 'Both players agreed to a draw.',
      stalemate: 'Draw triggered automatically due to the stalemate rule.',
      insufficient_material: 'Draw triggered automatically due to the insufficient material rule.',
      fivefold_repetition: 'Draw triggered automatically due to the fivefold repetition rule.',
      threefold_repetition: 'Draw claimed under the threefold repetition rule.',
      fifty_move: 'Draw claimed under the fifty move rule.'
    }

    win_message = {
      checkmate: 'Checkmate.',
      resignation: "#{ChessEngine::Colors.other(winner) unless winner == :draw} resigned.".capitalize
    }

    if winner == :draw
      puts draw_message.fetch(cause)
      puts 'Game drawn.'
    else
      puts win_message.fetch(cause)
      puts "#{winner} wins!".capitalize
    end

    puts "\nFEN: #{status.position.to_fen}"
  end

  def clear
    Gem.win_platform? ? system('cls') : system('clear')
  end

  # Input with a text directly before, on the same line
  def input(text)
    print text
    $stdout.flush
    gets.chomp
  end

  private

  # General helpers

  def pcenter(str, padding = ' ')
    puts center(str, padding)
  end

  def center(str, padding = ' ')
    padding_str = (WIDTH - str.size) / 2
    wrap_str(str, padding * padding_str)
  end

  # helper to wrap a string with given before and after strings
  # With no after given, assumes before and after are the same
  def wrap_str(str, before, after = nil)
    after ||= before
    "#{before}#{str}#{after}"
  end

  # Specific helpers

  def print_board(board)
    padding = ' ' * ((WIDTH - (8 * SQR_WIDTH) - 1) / 2)
    puts padding + file_labels
    board.each_rank.reverse_each.with_index do |row, r|
      rank_num = 8 - r
      piece_row = ''
      blank_row = ''
      row.each_with_index do |p, c|
        bg = (r + c).even? ? BG_LIGHT : BG_DARK

        piece_square = if p.nil?
                         BLANK
                       else
                         fg = p.color == :white ? FG_WHITE_PIECE : FG_BLACK_PIECE
                         piece_symbol = wrap_str(PIECES[:black][p.type], fg, bg)
                         wrap_str(piece_symbol, ' ' * (SQR_WIDTH / 2))
                       end

        blank_row += wrap_str(BLANK, bg, COLOR_RESET)
        piece_row += wrap_str(piece_square, bg, COLOR_RESET)
      end

      puts padding + wrap_str(blank_row, '  ')
      puts padding + wrap_str(piece_row, "#{rank_num} ", " #{rank_num}")
      puts padding + wrap_str(blank_row, '  ')
    end

    puts padding + file_labels
  end

  def print_status_bar(status)
    move_number = status.position.fullmove_number
    last_move = status.state.history.moves.last
    pcenter(
      " Move #{move_number}• Last: #{FORMATTER.call(last_move) || '-'} • #{status.current_color} to move ", '='
    )
    puts
    game_ending_stats = []
    game_ending_stats << 'In check!' if status.in_check?
    game_ending_stats << 'Draw offered' if status.offered_draw
    game_ending_stats << 'Draw claim available' if status.can_draw?
    pcenter(game_ending_stats.map { "<#{it}>" }.join('  '))
  end

  def captured_pieces_str(captured)
    captured.map do |color, pieces|
      "(#{color}) " + (if pieces.empty? then 'none'
                       else
                         pieces.tally.map do |piece, count|
                           count_str = count == 1 ? '' : " ×#{count}"
                           "#{PIECES[color][piece]}#{count_str}"
                         end.join(' ')
                       end)
    end.join(' | ')
  end

  def special_moves_bar(legal_moves)
    moves = []
    moves << 'en passant' if legal_moves.any? { it.is_a?(ChessEngine::EnPassantEvent) }
    moves << 'promotion' if legal_moves.any? { it.respond_to?(:promote) && !it.promote_to.nil? }

    castling_sides = legal_moves.select { it.is_a?(ChessEngine::CastlingEvent) }
                                .map { it.side == :kingside ? 'K' : 'Q' }
    moves << "castling(#{castling_sides.join(',')})" if castling_sides.any?

    moves.empty? ? '' : "Special moves: #{moves.join(', ')}"
  end

  # mid-game error messages
  def error_message(error)
    msg = case error
          when nil, :draw_offer_not_allowed
            'Everything looks OK'
          when :invalid_notation
            "Please enter a valid move or command ('h' for help)"
          when :invalid_event
            'You cannot make that move'
          when :draw_accept_not_allowed
            'You cannot accept a draw offer - no offer is being made'
          when :draw_claim_not_allowed
            'You are not eligible for draw claim'
          else
            raise 'The program encountered an unexpected error. quitting...'
          end
    "<#{msg}>"
  end

  def file_labels
    @file_labels ||= ChessEngine::Square::FILES.inject('  ') do |result, file|
      result + wrap_str(file, ' ' * (SQR_WIDTH / 2))
    end
  end

  def end_screen(title, board)
    clear
    pcenter('', '=')
    pcenter(" #{title} ", '=')
    pcenter('', '=')

    puts
    print_board(board)
    puts
  end
end

SimpleChessCli.new.start if __FILE__ == $PROGRAM_NAME
