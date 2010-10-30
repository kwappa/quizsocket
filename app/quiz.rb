# -*- coding: utf-8 -*-
require 'open-uri'
require 'json'

module QuizSocket
  class Question
    def initialize
      load_quiz
    end

    def question
      @current_question
    end

    def next_question
      load_quiz if !@quiz || @quiz.empty?
      @current_question = questionize @quiz.shift
    end

    def correct? answer
      answer.to_i == @current_question[:correct]
    end

    def load_quiz
      @quiz = JSON.parse API.new.get :all
      # DEBUG
      # @quiz = JSON.parse File.read(File.join(APP_ROOT, 'q.txt'))
    end

    def questionize question
      q = Hash.new
      q.store :question, question['question']
      q.store :answers,  question['answers'].sort_by{ rand }
      q.store :genre,    question['genre_name']
      q.store :correct,  q[:answers].index(question['answers'].first)
      q
    end

  end

  class Game

    STATE = {
      :init             =>     0,
      :entry            =>  1000,
      :question         =>  2000,
      :allow_answer     =>  2100,
      :recieve_answer   =>  2200,
      :show_result      =>  3000,
    }

    attr_accessor :channel

    def initialize channel
      @question = Question.new
      @channel = channel
      @state = STATE[:init]
      @count = 0
      @timer = EventMachine::add_periodic_timer(Rational 1, 10) { main_loop }
      @player = []
      @quiz = nil
    end

    def add_player ws
      @player << ws
    end

    def delete_player ws
      @player.delete ws
    end

    def players
      @player.count
    end

    def client_answer ws, num
      return unless allow_answer?
      set_state :recieve_answer
      @player.each do |player|
        if player.equal? ws
          player.send jsonize(num, @question.correct?(num) ? :right : :wrong)
        else
          player.send jsonize(nil, :lock)
        end
      end
    end

    def set_state key
      @state = STATE[key]
      @count = 0
      raise ArgumentError.new("invalid state [#{key.to_s}]") unless @state
    end

    def state? key
      @state && @state == STATE[key]
    end

    def allow_answer?
      state? :allow_answer
    end

    def main_loop
      @count += 1

      case @state

      when STATE[:init]
        # 初期化直後
        @channel.push_message "waiting"
        set_state :entry

      when STATE[:entry]
        # エントリ受付
        if @count > 5
          set_state :question
        end

      when STATE[:question]
        # 出題
        quiz = @question.next_question
        p quiz
        @channel.push_message JSON.generate(quiz), :question
        set_state :allow_answer

      when STATE[:allow_answer]
        # 解答待ち
        if @count > 50
          @channel.push_message nil, :lock
          set_state :show_result
        end

      when STATE[:recieve_answer]
        # 解答された
        set_state :show_result

      when STATE[:show_result]
        # 状況表示
        if @count > 20
          set_state :question
        end
      end

    end

  end

  class API
    API_KEY = 'ma6'
    GENRE_NAME = [
                  :humanities,        # 語学・文学・社会
                  :science,           # 科学・数学
                  :sports,            # スポーツ
                  :art,               # 映画・音楽・芸術
                  :entertainment,     # エンターテインメント
                  :variety,           # 雑学
                 ]
    API_URL = 'http://quizken.jp/api/quiz-index/api_key/' + API_KEY
    QUIZ_COUNT = 10

    def get genre = :all, count = QUIZ_COUNT
      query  = API_URL + '/'
      query += "genre_name/#{genre.to_s}/" if GENRE_NAME.include? genre
      query += "count/#{count}"
      OpenURI.open_uri(query).read
    end
  end

end
