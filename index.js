exports.handler = async (event) => {
  console.log('Received event', event);
  return { "message": "Hello from Lambda!" };
};
