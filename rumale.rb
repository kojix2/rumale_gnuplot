require 'numo/narray'
require 'numo/gnuplot'
require 'rumale'
require 'tempfile'

module ToyData
  include Numo

  # ドーナツ型（円）のトイデータをつくる
  def self.donut(n, r, θ = [0, 2])
    θ = DFloat.new(n).rand(*θ.map { |i| i * Math::PI })
    r = DFloat.new(n).rand(*r)
    x = r * NMath.cos(θ)
    y = r * NMath.sin(θ)
    [x, y].map { |i| yuragi(i) }
  end

  # 渦型のトイデータをつくる
  def self.galaxy(n, θ, rot = 0)
    θ = DFloat.new(n).rand(*θ.map { |i| i * Math::PI })
    x = θ * NMath.cos(θ + rot * Math::PI)
    y = θ * NMath.sin(θ + rot * Math::PI)
    [x, y].map { |i| yuragi(i) }
  end

  # 波型のトイデータをつくる
  def self.wave(n, xminmax, b)
    x = DFloat.new(n).rand(*xminmax)
    y = NMath.sin(x * Math::PI) + b
    [x, y].map { |i| yuragi(i, 0.2) }
  end

  def self.yuragi(x, sigma = 0.5)
    x + DFloat.new(x.size).rand_norm(0, sigma)
  end
end

module Tool
  class << self
    include Numo

    # ラベルを作る
    def labels(arr)
      nlabels = arr.map.with_index do |samples, idx|
        size = samples[0].size
        Array.new(size, idx)
      end

      nlabels.flatten!
      Numo::Int32[*nlabels]
    end

    # サンプルを作る
    def samples(arr)
      xs, ys = arr.transpose
      x = DFloat.hstack(xs)
      y = DFloat.hstack(ys)
      DFloat.vstack([x, y]).transpose
    end

    # サンプルをカバーするグリッドを作る
    def grid(samples)
      st = samples.transpose
      xs = st[0, true]
      ys = st[0, true]
      xmin, xmax = xs.minmax
      ymin, ymax = ys.minmax
      x = (DFloat.ones(200, 1) * DFloat.linspace(xmin, xmax, 200)).flatten
      y = (DFloat.ones(200, 1) * DFloat.linspace(ymin, ymax, 200)).transpose.flatten
      DFloat.vstack([x, y]).transpose
    end

    # resultでサンプルを分割する
    def split_samples(samples, result)
      xs = samples.transpose[0, true]
      ys = samples.transpose[1, true]
      x1 = xs[result.eq 0]
      x2 = xs[result.eq 1]
      y1 = ys[result.eq 0]
      y2 = ys[result.eq 1]
      [[x1, y1], [x2, y2]]
    end

    # トイデータのプロット用
    def gnuplot(s1, s2, base_name)
      Numo.gnuplot do
        reset
        set :term, :png
        set :out, base_name + '.png'
        set :noborder
        set :nokey
        set :notics
        set :origin, '0.1,0.1'
        set :size, '0.8,0.8'
        set :title, base_name
        plot [*s1, t: 's1', pt: 6, lw: 4], [*s2, t: 's2', pt: 6, lw: 4]
      end
    end

    # Rumale結果プロット用
    def sgnuplot(s1, s2, base_name, colors)
      color1 = colors[0]
      color2 = colors[1]
      z1 = Numo::DFloat.new(s1[0].size).fill(-1)
      z2 = Numo::DFloat.new(s2[0].size).fill(1)
      x1, y1 = s1
      x2, y2 = s2
      x = x1.concatenate x2
      y = y1.concatenate y2
      z = z1.concatenate z2

      # Missing blank lines 対策
      # https://stackoverflow.com/questions/32347580/empty-plot-gnuplot
      #
      x_uniq = x.sort.to_a.uniq
      datfile = Tempfile.open(['gnuplot', '.dat']) do |fp|
        x_uniq.each do |xu|
          sy = y[x.eq xu].sort
          sy.each do |yu|
            zi = (y.eq yu).where.to_a & (x.eq xu).where.to_a
            zu = z[zi[0]]
            if zu.respond_to? :size
              p zu
              raise
            end
            fp.puts "#{xu} #{yu} #{zu}"
          end
          fp.puts
        end
        fp
      end

      Numo.gnuplot do
        reset
        set :term, :png
        set :out, base_name + '.png'
        set :pm3d, :map
        set :nocolorbox
        set :noborder
        set :notics
        set :nokey
        set "palette defined (0 '#{color1}', 1 '#{color2}')"
        set :title, base_name
        splot '"' + File.expand_path(datfile.path) + '"'
      end
    end
  end
end

toydata = []

# トイデータ 銀河
s1 = ToyData.galaxy(100, [0, 2])
s2 = ToyData.galaxy(100, [0, 2], 1)
toydata << {
  name: :galaxy,
  data: [s1, s2],
  colors: ['#22fbb9', '#029ac1']
}

# トイデータ ドーナッツ
s1 = ToyData.donut(100, [0, 1.8])
s2 = ToyData.donut(100, [1.8, 3])
toydata << {
  name: :donut,
  data: [s1, s2],
  colors: ['#b11df0', '#4800d9']
}

# トイデータ デュオ
s1 = ToyData.donut(100, [0, 1])
s2 = ToyData.donut(100, [0, 1])
s1[0] += Numo::DFloat.new(100).fill(1.0)
s1[1] += Numo::DFloat.new(100).fill(0.2)
s2[0] += Numo::DFloat.new(100).fill(-1.0)
s2[1] += Numo::DFloat.new(100).fill(-0.2)
toydata << {
  name: :duo,
  data: [s1, s2],
  colors: ['#fa2a82', '#990096']
}

# トイデータ 波
s1 = ToyData.wave(100, [-2, 2], 0.5)
s2 = ToyData.wave(100, [-2, 2], -0.5)
toydata << {
  name: :wave,
  data: [s1, s2],
  colors: ['#fdd400', '#ff6600']
}

models = {
  DecisionTree: Rumale::Tree::DecisionTreeClassifier.new,
  NaiveBayes:   Rumale::NaiveBayes::GaussianNB.new,
  RandomForest: Rumale::Ensemble::RandomForestClassifier.new,
  KNeighbors:   Rumale::NearestNeighbors::KNeighborsClassifier.new,
  AdaBoost:     Rumale::Ensemble::AdaBoostClassifier.new
}

toydata.each do |td|
  data = td[:data]
  Tool.gnuplot(*data, td[:name].to_s)

  models.each do |model_name, model|
    samples = Tool.samples(data)
    labels  = Tool.labels(data)

    model.fit(samples, labels)

    test_samples = Tool.grid(samples)
    result = model.predict(test_samples)

    s12 = Tool.split_samples(test_samples, result)
    Tool.sgnuplot(*s12, "#{td[:name]}-#{model_name}", td[:colors])
  end
end
