#!/usr/bin/env bash
convert -append 'galaxy.png' 'galaxy-AdaBoost.png' 'galaxy-DecisionTree.png' 'galaxy-KNeighbors.png' 'galaxy-NaiveBayes.png' 'galaxy-RandomForest.png' z1.png
convert -append 'donut.png' 'donut-AdaBoost.png' 'donut-DecisionTree.png' 'donut-KNeighbors.png' 'donut-NaiveBayes.png' 'donut-RandomForest.png' z2.png
convert -append 'duo.png' 'duo-AdaBoost.png' 'duo-DecisionTree.png' 'duo-KNeighbors.png' 'duo-NaiveBayes.png' 'duo-RandomForest.png' z3.png
convert -append 'wave.png' 'wave-AdaBoost.png' 'wave-DecisionTree.png' 'wave-KNeighbors.png' 'wave-NaiveBayes.png' 'wave-RandomForest.png' z4.png
convert +append z1.png z2.png z3.png z4.png z.png
