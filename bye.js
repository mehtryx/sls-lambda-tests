'use strict';
function frf() {
  // Build the Elastic queryStruct - the 3-d array used for searching
  var frf = 'fmj';
}
module.exports.frf = frf;
// Sample Lambda function
module.exports.handler = (event, context, callback) => {
	var name = (event.name ? event.name : "nameless" );
  	const response = {
    	statusCode: 200,
    	body: JSON.stringify({
    		message: 'Goodbye ' + name,
      	  	input: event,
    	}),
  	};

  	callback(null, response);

  // Use this code if you don't use the http event with the LAMBDA-PROXY integration
  // callback(null, { message: 'Go Serverless v1.0! Your function executed successfully!', event });
  //hey look a code change, again
};
