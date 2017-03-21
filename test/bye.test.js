'use strict';
const expect = require( 'chai' ).expect;
const fmj = require( '../' );

describe( 'bye', function() {
	it('This is a test of tests. Good luck with that', function (done) {
    var ayy = fmj();
    expect( ayy ).to.eql( 'fmj' );
    done();
  });
});