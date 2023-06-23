import boto3
import datetime

ec2 = boto3.client('ec2')

def lambda_handler(event, context):
    current_time = datetime.datetime.now().time()
    current_weekday = datetime.datetime.now().weekday()

    # Configure the start and stop times for weekdays and weekends
    weekday_start_time = datetime.time(18, 0, 0)  # 6 PM
    weekday_stop_time = datetime.time(8, 0, 0)    # 8 AM

    weekend_start_time = datetime.time(0, 0, 0)    # 12 AM (midnight)
    weekend_stop_time = datetime.time(23, 59, 59)  # 11:59 PM

    if current_weekday < 5:  # Weekdays
        if current_time >= weekday_start_time or current_time <= weekday_stop_time:
            # Start the EC2 instances
            ec2.start_instances(InstanceIds=['instance-id-1', 'instance-id-2', 'instance-id-3'])
        else:
            # Stop the EC2 instances
            ec2.stop_instances(InstanceIds=['instance-id-1', 'instance-id-2', 'instance-id-3'])
    else:  # Weekends
        if current_time >= weekend_start_time and current_time <= weekend_stop_time:
            # Start the EC2 instances
            ec2.start_instances(InstanceIds=['instance-id-1', 'instance-id-2', 'instance-id-3'])
        else:
            # Stop the EC2 instances
            ec2.stop_instances(InstanceIds=['instance-id-1', 'instance-id-2', 'instance-id-3'])

