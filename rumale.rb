require 'numo/narray'
require 'numo/gnuplot'
require 'rumale'
require 'awesome_print'
require 'tempfile'

# 手抜き

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

  def self.yuragi(x)
    x + Numo::DFloat.new(x.size).rand_norm(0, 0.5)
  end
end

module MyTool
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


    def gnuplot(s1, s2, file_name)
      Numo.gnuplot do
        reset
        set :term, :png
        set :out, file_name
        set :title, file_name
        plot [*s1, t: 's1', pt: 6, lw: 4], [*s2, t: 's2', pt: 6, lw: 4]
      end
    end

    def sgnuplot(s1, s2, file_name)
      z1 = Numo::DFloat.new(s1[0].size).fill(-1)
      z2 = Numo::DFloat.new(s2[0].size).fill(1)
      x1, y1 = s1
      x2, y2 = s2
      x = x1.concatenate x2
      y = y1.concatenate y2
      z = z1.concatenate z2

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
        set :out, file_name
        set :pm3d, :map
        unset :colorbox
        set "palette defined (0 '#46e0d1', 1 '#059297')"
        unset :key
        set :title, file_name
        splot '"' + File.expand_path(datfile.path) + '"'
      end
    end
  end
end

s1 = ToyData.galaxy(100, [0, 2])
s2 = ToyData.galaxy(100, [0, 2], 1)
toydata0 = [s1, s2]

s1 = ToyData.donut(100, [0, 1.8])
s2 = ToyData.donut(100, [1.8, 3])
toydata1 = [s1, s2]

models = {
  DecisionTree: Rumale::Tree::DecisionTreeClassifier.new,
  NaiveBayes:   Rumale::NaiveBayes::GaussianNB.new,
  RandomForest: Rumale::Ensemble::RandomForestClassifier.new,
  KNeighbors:   Rumale::NearestNeighbors::KNeighborsClassifier.new(n_neighbors: 1),
  AdaBoost:     Rumale::Ensemble::AdaBoostClassifier.new,
}

[toydata0, toydata1].each_with_index do |td, index1|
  MyTool.gnuplot(*td, "toydata#{index1}.png")

  models.each do |name, model|
    samples = MyTool.samples(td)
    labels  = MyTool.labels(td)

    model.fit(samples, labels)

    test_samples = MyTool.grid(samples)
    result = model.predict(test_samples)

    s12 = MyTool.split_samples(test_samples, result)
    MyTool.sgnuplot(*s12, "#{name}-#{index1}.png")
  end
end
