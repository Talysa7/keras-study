# 3.4 영화 감상평 분류: 이항 분류 예제
# IMDB 데이터셋 사용

# 정리정돈
rm(list=ls())
path <- "C:/study/lecture/arbeit/keras-study"
setwd(path)

# 3.4.1 데이터셋 적재
# %<-% 다중 할당 연산자 사용
library(keras)
imdb <- dataset_imdb(num_words = 10000)
c(c(train_data, train_labels), c(test_data, test_labels)) %<-% imdb

# train_data와 test_data는 감상평을 담은 단어 인덱스 리스트
# train_labels와 test_labels는 0(부정)과 1(긍정)로 구성된 리스트
# 구조 확인
str(train_data[[1]])
str(train_labels[[1]])

# num_words = 10000: 훈련 데이터에서 출현 빈도 기준으로 상위 1만 개 단어만 유지한다는 의미
# 희박하게 나오는 단어를 제외해 처리 용량에 맞춰 벡터 데이터 구성 가능
# sapply는 주어진 벡터나 배열과 같은 길이의 리스트를 반환
# 9999개로 1만 개를 넘지 않음
# ?sapply
# max(sapply(train_data, max))

# 감상평 중 하나를 영어 단어로 빠르게 복호화하는 예제
# word_index는 단어를 정수 인덱스에 사상하는 이름이 부여된 리스트
word_index <- dataset_imdb_word_index()
# 정수 인덱스를 단어에 사상
reverse_word_index <- names(word_index)
names(reverse_word_index) <- word_index
# 감상평 복호화
decode_review <- sapply(train_data[[1]], function(index) {
    # 0, 1, 2는 채우기, 시퀀스 시작, 알려지지 않음을 위해 예약된 인덱스이므로 3만큼 인덱스 오프셋
    word <- if (index >= 3) reverse_word_index[[as.character(index - 3)]]
    if (!is.null(word)) word else "?"
})
# null인 경우 ?로 바뀌어 있음
str(decode_review)

# 3.4.2 데이터 준비
# 정수 리스트를 신경망에 공급(feed)할 수 없으므로 텐서로 변환해야 한다고...
# one-hot encoding으로 처리하는 방법 사용

# 정수 시퀀스를 이진 행렬로 부호화하기
vectorize_sequences <- function(sequences, dimension = 10000) {
    # (길이, 차원) 모양이고 모두가 0인 행렬 생성
    results <- matrix(0, nrow = length(sequences), ncol = dimension)
    # 해당 행렬의 [i]의 특정 인덱스를 1로 설정
    for (i in 1:length(sequences))
        results[i, sequences[[i]]] <- 1
    results
}

# 위 함수로 훈련용, 테스트용 데이터 처리
x_train <- vectorize_sequences(train_data)
x_test <- vectorize_sequences(test_data)

# 만들어진 표본 구조 확인하기
# [1:10000] 1 1 0 1 1 1 1 1 1 0 ...
str(x_train[1,])

# 원래는 어땠더라...
str(train_data[1])

# 레이블을 정수에서 숫자형으로 변환하기
y_train <- as.numeric(train_labels)
y_test <- as.numeric(test_labels)

# 확인해보기
# 자료형이 int에서 num으로 바뀌었다
str(train_labels[1])
str(y_train[1])

# 3.4.3 망 구축
# 모델 정의하기
# 3개 계층의 망, 첫 번째와 두 번째는 ReLU를 통해 음수인 값을 0으로, 세 번째는 Sigmoid를 통해 구간을 0, 1로 축소
model <- keras_model_sequential() %>%
    layer_dense(units = 16, activation = "relu", input_shape = c(10000)) %>%
    layer_dense(units = 16, activation = "relu") %>%
    layer_dense(units = 1, activation = "sigmoid")

# 모델 컴파일
# 최적화기로 rmsprop, 손실 함수로 binary_crossentropy, 계량 함수에는 accuracy 적용
# 교차 엔트로피는 정보 이론 분야에서 확률 분포 사이의 거리를 측정하는 양, 확률 산출 모델을 다룰 때 좋음
# 참고: https://onesixx.com/optimizer-loss-metrics/
model %>% compile(
    optimizer = "rmsprop",
    loss = "binary_crossentropy",
    metrics = c("accuracy")
)

# 최적화기의 파라미터를 구성하거나 사용자 정의 손실 함수를 전달하려면 인수를 사용
# 최적화기 구성하기 예제, optimizer_rmsprop 함수에 lr 값 지정, lr 값은 학습률(Learning rate)
# ? optimizer_rmsprop()
# model %>% compile(
#    optimizer <- optimizer_rmsprop(lr=0.001),
#    loss <- "binary_crossentropy",
#    metrics <- c("accuracy")
#)

# 3.4.4 접근 방식 검증하기
# 새로운 데이터에 대한 모델 정확도를 훈련 중에 관측하기 위해 표본을 설정해 검증 집합 작성
val_indices <- 1:10000

x_val <- x_train[val_indices,]
partial_x_train <- x_train[-val_indices,]

y_val <- y_train[val_indices]
partial_y_train <- y_train[-val_indices]

# 512개 표본으로 구성된 미니 배치로 모든 표본을 대상으로 20회 반복해 모델 학습(20에포크)
# 설정한 1만 개 표본에서 손실 및 정확도 관측하기
# history 객체는 모델과 각 계량 데이터를 저장하는 데 사용되는 파라미터를 포함함
history <- model %>% fit(
    partial_x_train,
    partial_y_train,
    epochs = 20,
    batch_size = 512,
    validation_data = list(x_val, y_val)
)

# 훈련 계량 및 검증 계량 시각화
# 훈련 손실은 모든 에포크마다 줄어들고, 훈련의 정확도는 증가
plot(history)

# 과적합을 방지하기 위해 훈련 중단하기
# 성능 및 효율이 좋아보이는 에포크까지만 훈련시켜 결과 확인해보기
model <- keras_model_sequential() %>%
    layer_dense(units = 16, activation = "relu", input_shape = c(10000)) %>%
    layer_dense(units = 16, activation = "relu") %>%
    layer_dense(units = 1, activation = "sigmoid"
)

model %>% compile(
    optimizer = "rmsprop",
    loss = "binary_crossentropy",
    metrics = c("accuracy")
)

model %>% fit(x_train, y_train, epochs = 4, batch_size = 512)
results <- model %>% evaluate(x_test, y_test)

# 결과 확인하기, 정확도 약 88%
results

# 3.4.5 훈련된 망을 사용해 신규 데이터에 대한 예측 생성하기
# predict()로 긍정적인 감상평일 가능성 보기
# 1에 가까울수록 긍정적인 감상평일 가능성이 높음
model %>% predict(x_test[1:10,])

# 3.4.6 추가 실험

# 은닉 계층 수를 1개 또는 3개 사용해 정확도에 미치는 영향 보기
# 은닉 계층 수 1개인 경우, 활성 함수 동일하게 ReLU, 에포크 동일하게 30으로 확인해보기
model <- keras_model_sequential() %>%
    layer_dense(units = 16, activation = "relu", input_shape = c(10000)) %>%
    layer_dense(units = 1, activation = "sigmoid"
)

model %>% compile(
    optimizer = "rmsprop",
    loss = "binary_crossentropy",
    metrics = c("accuracy")
)

model %>% fit(x_train, y_train, epochs = 30, batch_size = 512)

# 은닉 계층 1개인 경우의 결과 확인, 정확도가 84%로 더 낮음, 손실은 0.77로 더 높음, 소요 시간 더 짧음
results <- model %>% evaluate(x_test, y_test)
results

# 은닉 계층 수가 3개인 경우, 활성 함수 동일하게 ReLU, 에포크 동일하게 30
model <- keras_model_sequential() %>%
    layer_dense(units = 16, activation = "relu", input_shape = c(10000)) %>%
    layer_dense(units = 16, activation = "relu") %>%
    layer_dense(units = 16, activation = "relu") %>%
    layer_dense(units = 1, activation = "sigmoid"
)

model %>% compile(
    optimizer = "rmsprop",
    loss = "binary_crossentropy",
    metrics = c("accuracy")
)

model %>% fit(x_train, y_train, epochs = 30, batch_size = 512)

# 은닉 계층 3개인 경우의 결과 확인, 정확도가 84%로 더 낮음, 손실은 1.49로 더 높음, 소요시간 더 짧음
results <- model %>% evaluate(x_test, y_test)
results

# 은닉 유닛 수를 다르게 하여 확인해보기
# 은닉 유닛 수 32, 은닉 계층 2개, 에포크 30
model <- keras_model_sequential() %>%
    layer_dense(units = 32, activation = "relu", input_shape = c(10000)) %>%
    layer_dense(units = 32, activation = "relu") %>%
    layer_dense(units = 1, activation = "sigmoid"
)

model %>% compile(
    optimizer = "rmsprop",
    loss = "binary_crossentropy",
    metrics = c("accuracy")
)

model %>% fit(x_train, y_train, epochs = 30, batch_size = 512)

# 은닉 유닛 32개인 경우 결과 확인, 정확도 85%로 더 낮음, 손실 1.29로 더 큼, 시간 약간 더 적게 걸림
results <- model %>% evaluate(x_test, y_test)
results

# 은닉 유닛 수 64개
model <- keras_model_sequential() %>%
    layer_dense(units = 64, activation = "relu", input_shape = c(10000)) %>%
    layer_dense(units = 64, activation = "relu") %>%
    layer_dense(units = 1, activation = "sigmoid"
)

model %>% compile(
    optimizer = "rmsprop",
    loss = "binary_crossentropy",
    metrics = c("accuracy")
)

model %>% fit(x_train, y_train, epochs = 30, batch_size = 512)

# 은닉 유닛 64개인 경우 결과 확인 정확도 85%로 더 낮음, 손실 1.29로 더 큼, 시간 더 오래 걸림
results <- model %>% evaluate(x_test, y_test)
results

# 은닉 유닛 수, 은닉 계층 수를 적절히 조절하는 게 성능과 정확도 측면에서 더 유익
# 정확도도 중요하지만 손실 측면에서도 추가 실험한 경우들은 유익하지 않았음

# 손실 함수를 binary_crossentropy에서 mse로 변경해보기
# binary_crossentropy는 확률 형태의 예측 결과를 다룰 때 좋음
# mse는 평균 제곱 오차(Mean Squared Error)로 모델의 출력 값과 원하는 출력 값 사이의 거리를 오차로 사용, 계산이 간편
model <- keras_model_sequential() %>%
    layer_dense(units = 16, activation = "relu", input_shape = c(10000)) %>%
    layer_dense(units = 16, activation = "relu") %>%
    layer_dense(units = 1, activation = "sigmoid"
)

model %>% compile(
    optimizer = "rmsprop",
    loss = "mse",
    metrics = c("accuracy")
)

model %>% fit(x_train, y_train, epochs = 30, batch_size = 512)

# 손실 함수를 mse로 한 경우 결과 확인, 정확도는 85%로 더 낮지만 손실이 0.13으로 크게 줄어들었음, 시간은 비슷하게 걸림
results <- model %>% evaluate(x_test, y_test)
results

# 활성 함수를 ReLU가 아닌 Tanh 사용해보기
# Tanh는 Sigmoid와 유사하지만 출력 값의 평균이 0
# 참고: https://ganghee-lee.tistory.com/32
model <- keras_model_sequential() %>%
    layer_dense(units = 16, activation = "tanh", input_shape = c(10000)) %>%
    layer_dense(units = 16, activation = "tahn") %>%
    layer_dense(units = 1, activation = "sigmoid"
)

model %>% compile(
    optimizer = "rmsprop",
    loss = "binary_crossentropy",
    metrics = c("accuracy")
)

model %>% fit(x_train, y_train, epochs = 30, batch_size = 512)

# 활성 함수로 tanh를 사용한 경우 결과 확인, 정확도는 83%, 손실은 0.99로 더 나쁜 결과, 시간은 약간 적게 걸림
results <- model %>% evaluate(x_test, y_test)
results

# 에포크가 반복될수록 지나치게 높은 정확도(Accuracy)를 보이며 모델이 과적합되기도 함
# 은닉 계층 및 유닛, 활성 함수, 손실 함수를 어떻게 설정하는지에 따라 결과와 효율이 달라짐