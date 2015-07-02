part of api;

@app.Interceptor(r'/.*')
authFilter() {
    print(app.request.url);
    // for right now, let all requests through
    app.chain.next();
    // we need to authenticate based on both GitHub and Google though
}