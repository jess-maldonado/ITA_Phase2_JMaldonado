FROM golang:alpine

ENV GO111MODULE=on

RUN mkdir /app

ADD . /app/

WORKDIR /app

RUN go mod download

COPY . /app/

RUN go build -o main .

EXPOSE 8080

CMD ["./main"]
