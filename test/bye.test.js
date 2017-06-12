'use strict';

//Two step test take 2

const expect = require( 'chai' ).expect;
const fmj = require( '../bye.js' );

describe( 'Test Suite 1', function() {
	it('This is a test of tests. Good luck with that', function (done) {
	    var ayy = fmj.frf();
	    expect( ayy ).to.eql( 'fmj' );
	done();
  });
	it('bye again', function (done) {
		var ayy = 'fmj';
    	expect( ayy ).to.eql( 'fmj' )
    	done();
	});
	it('A test name', function (done) {
		var ayy = 'travis_eaten_by_suave_shark';
    	expect( ayy ).to.eql( 'not_what_i_expected' )
    	done();
	});
});
describe( 'Test Suite 2', function() {
	it('This is a failing test of tests. Good luck with that', function (done) {
	    var ayy = fmj.frf();
	    expect( ayy ).to.eql( 'jmf' );
	done();
  });
	it('bye again', function (done) {
		var ayy = fmj.frf();
    	expect( ayy ).to.eql( 'fmj' )
    	done();
	});
	it('Another test name', function (done) {
		var ayy = 'spanish_inquisition';
    	expect( ayy ).to.eql( 'also_not_what_i_expected' )
    	done();
	});
});