'use strict';

//Once more with feeling

const expect = require( 'chai' ).expect;
const fmj = require( '../bye.js' );

describe( 'bye', function() {
	it('This is a test of tests. Good luck with that', function (done) {
	    var ayy = fmj.frf();
	    expect( ayy ).to.eql( 'fmj' );
    	done();
  });
	it('uh oh', function (done) {
		var ayy = fmj.frf();
    	expect( ayy ).to.eql( 'not fmj' )
    	done();
	});
});