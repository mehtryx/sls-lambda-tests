#!/bin/sh

# The script is taking four paramerters as arguments: 1) aws cli profile user to access aws resouces like dynamoDB, 2)Git repostitory url used in current deployment, 3)Merged branch name (example: staging) and 4)Merging branch name (example: hotfix/wpt-script-bug-fix)
# All other variables related to WebPageTest Performance Test API and WCM API are set from Environment variables

wpt_pull_api_token=`echo $WPT_PULL_API_TOKEN`
wpt_number_of_tests=`echo $WPT_NUMBER_OF_TESTS`
wpt_pull_api_label=`echo $WPT_PULL_API_LABEL`
wpt_pull_api_location=`echo $WPT_PULL_API_LOCATION`
wpt_metric_count=2
wpt_first_view_only=`echo $WPT_FIRST_VIEW_ONLY`
wpt_pull_api_request_id=`echo $$`
wcm_api_url=`echo $WCM_API_URL`
wcm_api_key=`echo $WCM_API_KEY`
raw_data_file_type="xml"
is_wcm_api_url=`echo $IS_WCM_API_URL`
aws_cli_profile_user=`echo $1`
repository_url=`echo $2`
merged_branch_name=`echo $3`
merging_branch_name=`echo $4`
number_of_arguments=`echo $#`
current_dir=`pwd`
cd $current_dir

# Function for insert/updating test result into database. this function also gets the OLD data and writes into logfile
function db_insert_test_result() {
    status=`echo $1`
    db_query_response=`aws dynamodb query --profile $aws_cli_profile_user --table-name 'wpt-performance-test-result' --index-name 'git_repository-merging_branch-index' --key-condition-expression 'git_repository = :repo and merging_branch = :mgb' --projection-expression 'id' --filter-expression 'merged_branch = :mdb' --expression-attribute-values '{ ":repo": {"S": '\"$repository_url\"'}, ":mgb": {"S": '\"$merging_branch_name\"'}, ":mdb": {"S": '\"$merged_branch_name\"'} }'`
    count=`echo $db_query_response | jq -r '.Count'`
    primary_id=`echo $db_query_response | jq -r '.Items[0].id.N'`
    db_update_time=`date -u +"%Y-%m-%dT%H:%M:%SZ"`
    timestamp=$(date +%s)
    if [ "$count" -ne "0" ] ; then
        db_query_response=`aws dynamodb update-item --profile $aws_cli_profile_user --table-name 'wpt-performance-test-result' --return-values ALL_OLD --key '{ "id": {"N": '\"$primary_id\"'} }' --update-expression 'SET test_status = :st, modified_on = :mo, avg_loadTime = :alt, avg_TTFB = :atfb, wpt_TestID = :tid' --expression-attribute-values '{ ":st": {"S": '\"$status\"'}, ":mo": {"S": '\"$db_update_time\"'}, ":alt": {"N": '\"$avg_loadTime\"'}, ":atfb": {"N": '\"$avg_TTFB\"'}, ":tid": {"S": '\"$testId\"'} }'`
    else
    db_query_response=`aws dynamodb put-item --profile $aws_cli_profile_user --table-name 'wpt-performance-test-result' --return-consumed-capacity TOTAL --return-values ALL_OLD --item '{ "id": {"N": '\"$timestamp\"'}, "git_repository": {"S": '\"$repository_url\"'}, "merging_branch": {"S": '\"$merging_branch_name\"'}, "merged_branch": {"S": '\"$merged_branch_name\"'}, "test_status": {"S": '\"$status\"'}, "avg_loadTime": {"N": '\"$avg_loadTime\"'}, "avg_TTFB": {"N": '\"$avg_TTFB\"'}, "created_on": {"S": '\"$db_update_time\"'}, "modified_on": {"S": '\"$db_update_time\"'}, "wpt_TestID": {"S": '\"$testId\"'} }'`
    fi
    
    previous_ttfb=`echo $db_query_response | jq -r '.Attributes.avg_TTFB.N'`
    previous_loadTime=`echo $db_query_response | jq -r '.Attributes.avg_loadTime.N'`

    echo "Test resutl is inserted into database" >> wpt_performance_test_execution.log
    echo "Previous Deployment Result: avgLoadTime:$previous_loadTime & avgTTFB:$previous_ttfb on Repo: $repository_url into branch $merged_branch_name from $merging_branch_name branch" | tee -a wpt_performance_test_execution.log
}

# Function for doing performance test and compare current performance data with threshold value
function do_test() {

    # Writing the API Response in a newly created file named response.xml and get the status code from the response
    # You have to install xmllint into the EC2 instance if its not there (usually its installed with AWS Linux AMI). xmllint is used to parse the xml file
    # If we run 5-10 tests, it will take time to finish all test. So an explicit sleep for 5sec is added
    # Using the testStatus API, checking the status whether all tests are finished successfully (200) or not (100=In-Progress, 101=In-Queue)
    # Performance raw data is written into a xml file named raw_data.xml
    {
    # API for Private Instance configured in AWS with Location Parameter
        # api_response=`curl -H "x-api-key: $wcm_api_key" "http://ec2-34-206-2-214.compute-1.amazonaws.com/runtest.php?url=$wcm_api_url&runs=$wpt_number_of_tests&f=$raw_data_file_type&r=$wpt_pull_api_request_id&label=$wpt_pull_api_label&location=$wpt_pull_api_location&k=$wpt_pull_api_token&fvonly=$wpt_first_view_only"`

    if [ $is_wcm_api_url ] ; then
        # API for Private Instance configured in AWS - without Location, so it will choose default location
        api_response=`curl -H "x-api-key: $wcm_api_key" "http://ec2-34-206-2-214.compute-1.amazonaws.com/runtest.php?url=$wcm_api_url&runs=$wpt_number_of_tests&f=$raw_data_file_type&r=$wpt_pull_api_request_id&label=$wpt_pull_api_label&&location=$wpt_pull_api_location&k=$wpt_pull_api_token&fvonly=$wpt_first_view_only"`
    else
        # API for web 2.0 sites and also without Location
        api_response=`curl "http://ec2-34-206-2-214.compute-1.amazonaws.com/runtest.php?url=$wcm_api_url&runs=$wpt_number_of_tests&f=$raw_data_file_type&r=$wpt_pull_api_request_id&label=$wpt_pull_api_label&&location=$wpt_pull_api_location&k=$wpt_pull_api_token&fvonly=$wpt_first_view_only"`
    fi

        echo $api_response > response.xml
    } &> /dev/null

    statusCode=`/usr/bin/xmllint --xpath '//response/statusCode/text()' response.xml`
    statusText=`/usr/bin/xmllint --xpath '//response/statusText/text()' response.xml`

    if [ $statusCode -eq 200 ] ; then
        testId=`/usr/bin/xmllint --xpath '//response/data/testId/text()' response.xml`
        xmlUrl=`/usr/bin/xmllint --xpath '//response/data/xmlUrl/text()' response.xml`
        jsonUrl=`/usr/bin/xmllint --xpath '//response/data/jsonUrl/text()' response.xml`
        userUrl=`/usr/bin/xmllint --xpath '//response/data/userUrl/text()' response.xml`
        echo "Running test $testId and waiting to get performance data for all $wpt_number_of_tests tests..." >> wpt_performance_test_execution.log
        sleep 5s
        while true;
        do
            {
                check_status_api_response=`curl "http://ec2-34-206-2-214.compute-1.amazonaws.com/testStatus.php?f=xml&test=$testId"`
                echo $check_status_api_response > check_status_response.xml
            } &> /dev/null

            check_statusCode=`/usr/bin/xmllint --xpath '//response/statusCode/text()' check_status_response.xml`
            check_statusText=`/usr/bin/xmllint --xpath '//response/statusText/text()' check_status_response.xml`

            if [ $check_statusCode -eq 200 ] ; then
                {
                    raw_data=`curl "$xmlUrl?r=$wpt_pull_api_request_id"`
                    echo $raw_data > raw_data.xml
                } &> /dev/null
            
                echo "Performance Data has been written into raw_data.xml file successfully" >> wpt_performance_test_execution.log
                dt=`date`
                echo "WebPageTest API returns data successfully - time: "$dt >> wpt_performance_test_execution.log
                break;
            elif [[ $check_statusCode -ne 200 && $check_statusCode -ne 100 && $check_statusCode -ne 101 ]] ; then
                echo "Error in test with response code: "$check_statusCode >> wpt_performance_test_execution.log
                echo "Check check_status_response.xml file for detail message" >> wpt_performance_test_execution.log
                dt=`date`
                echo "WebPageTest API Failed - time: "$dt >> wpt_performance_test_execution.log
                exit 1
            fi
            echo "Test ID $testId - Current Status is: $check_statusText" >> wpt_performance_test_execution.log
            sleep 2s
        done
    else
        echo "WPT Performance Test was not executed due to: "$statusText
        dt=`date`
        echo "WPT Performance Test was not executed due to $statusText - time: "$dt >> wpt_performance_test_execution.log
        exit 1
    fi

    curr_data_file="$current_dir/raw_data.xml"

    read loadTime TTFB render requestsFull fullyLoaded fullyLoadedBytes server_rtt SpeedIndex <<<$(echo 0 0 0 0 0 0 0 0)


    # Calculating the average value of each metric
    k=0
    for ((i=1; i<=$wpt_number_of_tests; i++)) ;
    do
        data[$k]=`/usr/bin/xmllint --xpath '//response/data/run['"$i"']/firstView/results/loadTime/text()' "$curr_data_file"`
        loadTime=`expr $loadTime + ${data[$k]}`
        echo "loadTime for Test[$i] => ${data[$k]}" >> wpt_performance_test_execution.log
        ((k++))

        data[$k]=`/usr/bin/xmllint --xpath '//response/data/run['"$i"']/firstView/results/TTFB/text()' "$curr_data_file"`
        TTFB=`expr $TTFB + ${data[$k]}`
        echo "TTFB for Test[$i] => ${data[$k]}" >> wpt_performance_test_execution.log
        ((k++))
    done

    avg_loadTime=$(echo "scale=0; $loadTime/$wpt_number_of_tests" | bc)
    avg_TTFB=$(echo "scale=0; $TTFB/$wpt_number_of_tests" | bc)

    # Connecting to dynamoDB to get threshold data from wpt-performance-metric-threshold table
    # Used AWS CLI to connecto with dynamoDB
    # The table structure for two metric: id(number), loadTime(number), ttfb(number), api_url(string), api_description(string)
    # You need jq to be installed into EC2 for json data parsing
    dt=`date`
    echo "Connecting to dynamoDB to get threshold data - time: "$dt >> wpt_performance_test_execution.log

    query_resp=`aws dynamodb query --profile $aws_cli_profile_user --table-name 'wpt-performance-metric-threshold' --key-condition-expression 'api_url = :api' --expression-attribute-values '{ ":api": {"S": '\"$wcm_api_url\"'} }'`
    count=`echo $query_resp | jq -r '.Count'`

    if [ "$count" -ne "0" ] ; then
        loadTime_threshold=`echo $query_resp | jq -r '.Items[0].loadTime.N'`
        ttfb_threshold=`echo $query_resp | jq -r '.Items[0].ttfb.N'`
    else
        echo "Metric Threshold values are not defined for API: $wcm_api_url" | tee -a wpt_performance_test_execution.log
        exit 1
    fi

    # Preparing the test resutl
    success_flag=0
    echo "WebPageTest Performance Test Suite Result (average of $wpt_number_of_tests runs):" | tee -a wpt_performance_test_execution.log

    if [ $avg_loadTime -gt $loadTime_threshold ] ; then
        echo "loadTime test FAILED. Current average loadTime(ms) $avg_loadTime is greater than threshold value $loadTime_threshold" | tee -a wpt_performance_test_execution.log
    else
        ((success_flag++))
        echo "loadTime test PASSED. Current average loadTime(ms) $avg_loadTime is smaller than threshold value $loadTime_threshold" | tee -a wpt_performance_test_execution.log
    fi

    if [ $avg_TTFB -gt $ttfb_threshold ] ; then
        echo "TTFB test FAILED. Current average TTFB(ms) $avg_TTFB is greater than threshold value $ttfb_threshold" | tee -a wpt_performance_test_execution.log
    else
        ((success_flag++))
        echo "TTFB test PASSED. Current average TTFB(ms) $avg_TTFB is smaller than threshold value $ttfb_threshold" | tee -a wpt_performance_test_execution.log
    fi

    # Setting the exit mode of this script. If any test fails, then exit(1) - should fail the Jenkins Build
    
    dt=`date`
    echo "PASSED $success_flag test(s) out of $wpt_metric_count Performance Metric Tests." | tee -a wpt_performance_test_execution.log

    echo "View Test result in web: $userUrl" >> wpt_performance_test_execution.log
    echo "View xmlResult rawdata: $xmlUrl" >> wpt_performance_test_execution.log

    if [ $success_flag -lt $wpt_metric_count ] ; then
        echo "WPT test failed - time: "$dt >> wpt_performance_test_execution.log
        db_insert_test_result "fail"
        exit 1
    else
        echo "WPT test finished successfully - time: "$dt >> wpt_performance_test_execution.log
        db_insert_test_result "pass"
        exit 0
    fi
}

         
# To track the timing of each step and resutl, start writing a log file. So user write permission is requried to present-working-directory
dt=`date`
echo "Test start time: "$dt > wpt_performance_test_execution.log

if [ $number_of_arguments -ne 4 ] ; then
    echo "WebPageTest Performance Test not executed. You have to pass 4 paramerters as following order: 1)AWS profile username, 2)Git-hub Repo url used in current deployment, 3)Merged branch name (example: staging) and 4)Merging branch name (example: hotfix/wpt-script-bug-fix)" | tee -a wpt_performance_test_execution.log
    exit 1
else
    if [ "$merged_branch_name" == "staging" ] ; then

# Query DynamoDB wpt-performance-test-result table to featch the previous test-status when the branch was merged into QA environment
# Next step is: if the previous test on QA environment is passed, we will do test on Staging otherwise not
        query_resp=`aws dynamodb query --profile $aws_cli_profile_user --table-name 'wpt-performance-test-result' --index-name 'git_repository-merging_branch-index' --projection-expression 'test_status, merged_branch' --key-condition-expression 'git_repository = :repo and merging_branch = :mgb' --filter-expression 'merged_branch = :mdb' --expression-attribute-values '{ ":repo": {"S": '\"$repository_url\"'}, ":mgb": {"S": '\"$merging_branch_name\"'}, ":mdb": {"S": "qa"} }'`
        test_status=`echo $query_resp | jq -r '.Items[0].test_status.S'`
        merged_branch=`echo $query_resp | jq -r '.Items[0].merged_branch.S'`
        
        if [ "$test_status" == "pass" -a "$merged_branch" == "qa" ] ; then
            echo "Code was passed on QA, now started performance testing on Staging environment" >> wpt_performance_test_execution.log
            do_test
        else
            echo "WebPageTest Performance test was not passed in QA environment for $merging_branch_name branch. Before moving to Staging, your code has to pass Performance test it on QA" | tee -a wpt_performance_test_execution.log
            exit 1
        fi
    else        
        echo "Performance test on QA environment" >> wpt_performance_test_execution.log
        do_test
    fi
fi