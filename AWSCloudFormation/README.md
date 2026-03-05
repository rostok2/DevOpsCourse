# №20. AWS CloudFormation

### Створення базової мережевої інфраструктури vpc_network.yaml

```bash
AWSTemplateFormatVersion: '2010-09-09'
Description: Creates VPC, Public Subnet, IGW, and Route Table.

Resources:
  MyVPC:
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock: 10.0.0.0/16
      EnableDnsSupport: 'true'
      EnableDnsHostnames: 'true'
      Tags:
        - Key: Name
          Value: NetworkVPC

  PublicSubnet:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref MyVPC
      CidrBlock: 10.0.1.0/24
      AvailabilityZone: !Sub "${AWS::Region}a"
      MapPublicIpOnLaunch: 'true'
      Tags:
        - Key: Name
          Value: PublicSubnet

  InternetGateway:
    Type: AWS::EC2::InternetGateway

  AttachGateway:
    Type: AWS::EC2::VPCGatewayAttachment
    Properties:
      VpcId: !Ref MyVPC
      InternetGatewayId: !Ref InternetGateway

  RouteTable:
    Type: AWS::EC2::RouteTable
    Properties:
      VpcId: !Ref MyVPC
      Tags:
        - Key: Name
          Value: PublicRouteTable

  DefaultRoute:
    Type: AWS::EC2::Route
    DependsOn: AttachGateway
    Properties:
      RouteTableId: !Ref RouteTable
      DestinationCidrBlock: 0.0.0.0/0
      GatewayId: !Ref InternetGateway

  SubnetRouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId: !Ref PublicSubnet
      RouteTableId: !Ref RouteTable

Outputs:
  VPCId:
    Description: VPC ID
    Value: !Ref MyVPC
  PublicSubnetId:
    Description: Public Subnet ID
    Value: !Ref PublicSubnet
```

### Створення дозволів для EC2 iam_role.yaml

```bash
AWSTemplateFormatVersion: '2010-09-09'
Description: Creates IAM Role for EC2 with S3 Read-Only access.

Resources:
  EC2S3Role:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: ec2.amazonaws.com
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess
      RoleName: IAMRoleForS3Access

  EC2InstanceProfile:
    Type: AWS::IAM::InstanceProfile
    Properties:
      Path: "/"
      Roles:
        - !Ref EC2S3Role

Outputs:
  IAMRoleARN:
    Description: ARN of the IAM Role
    Value: !GetAtt EC2S3Role.Arn
  InstanceProfileName:
    Description: Name of the IAM Instance Profile
    Value: !Ref EC2InstanceProfile
```

### Створення приватного сховища даних s3_bucket.yaml

```bash
AWSTemplateFormatVersion: '2010-09-09'
Description: Creates a private S3 Bucket with versioning and policy.

Parameters:
  BucketNameParam:
    Type: String
    Description: my-unique-data-bucket-cf-2024
    Default: your-unique-cf-s3-bucket-03-xyz 

Resources:
  DataBucket:
    Type: AWS::S3::Bucket
    DeletionPolicy: Retain
    Properties:
      BucketName: !Ref BucketNameParam
      VersioningConfiguration:
        Status: Enabled
      PublicAccessBlockConfiguration:
        BlockPublicAcls: true
        BlockPublicPolicy: true
        IgnorePublicAcls: true
        RestrictPublicBuckets: true

  BucketPolicy:
    Type: AWS::S3::BucketPolicy
    Properties:
      Bucket: !Ref DataBucket
      PolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Sid: DenyPublicAccess
            Effect: Deny
            Principal: "*"
            Action: s3:*
            Resource:
              - !Sub "arn:aws:s3:::${DataBucket}"
              - !Sub "arn:aws:s3:::${DataBucket}/*"
            Condition:
              Bool:
                aws:SecureTransport: 'false'

Outputs:
  S3BucketName:
    Description: The name of the created S3 Bucket.
    Value: !Ref DataBucket
```

### Створення віртуальної машини ec2_compute.yaml

```bash
AWSTemplateFormatVersion: '2010-09-09'
Description: Creates EC2 instance using resources from other stacks.

Parameters:
  VPCId:
    Type: String
    Description: VPC ID from Network Stack
  SubnetId:
    Type: String
    Description: Public Subnet ID from Network Stack
  InstanceProfileName:
    Type: String
    Description: Instance Profile Name from IAM Stack
  AMIID:
    Type: String
    Description: AMI ID for Amazon Linux 2
    Default: ami-08d70e59c07c61a3a 

Resources:
  InstanceSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: Enable SSH access
      VpcId: !Ref VPCId
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 22
          ToPort: 22
          CidrIp: 0.0.0.0/0

  EC2Instance:
    Type: AWS::EC2::Instance
    Properties:
      InstanceType: t2.micro
      ImageId: !Ref AMIID
      SubnetId: !Ref SubnetId
      IamInstanceProfile: !Ref InstanceProfileName
      SecurityGroupIds:
        - !Ref InstanceSecurityGroup
      Tags:
        - Key: Name
          Value: FinalEC2Instance

Outputs:
  EC2PublicIP:
    Description: Public IP address of the EC2 instance.
    Value: !GetAtt EC2Instance.PublicIp
```

### Заходимо до веб морди AWS 

там створюємо bucket(my-templates-for-cf-stack-12345) та завантажуємо 4 попередє створені файли

### Створення який створить стек CloudFormation main_stack.yaml
```bash
AWSTemplateFormatVersion: '2010-09-09'
Description: Main Stack to orchestrate all other component stacks.

Parameters:
  BucketNameParam:
    Type: String
    Description: my-unique-data-bucket-cf-2024
  AMIID:
    Type: String
    Description: AMI ID для Amazon Linux 2 в us-east-2.

Resources:
  NetworkStack:
    Type: AWS::CloudFormation::Stack
    Properties:
      TemplateURL: !Sub 'https://my-templates-for-cf-stack-12345.s3.amazonaws.com/vpc_network.yaml'
      Parameters: {}

  IAMStack:
    Type: AWS::CloudFormation::Stack
    DependsOn: NetworkStack
    Properties:
      TemplateURL: !Sub 'https://my-templates-for-cf-stack-12345.s3.amazonaws.com/iam_role.yaml'
      Parameters: {}

  S3Stack:
    Type: AWS::CloudFormation::Stack
    Properties:
      TemplateURL: !Sub 'https://my-templates-for-cf-stack-12345.s3.amazonaws.com/s3_bucket.yaml'
      Parameters:
        BucketNameParam: !Ref BucketNameParam

  EC2Stack:
    Type: AWS::CloudFormation::Stack
    DependsOn: 
      - NetworkStack
      - IAMStack
      - S3Stack
    Properties:
      TemplateURL: !Sub 'https://my-templates-for-cf-stack-12345.s3.amazonaws.com/ec2_compute.yaml'
      Parameters:
        VPCId: !GetAtt NetworkStack.Outputs.VPCId
        SubnetId: !GetAtt NetworkStack.Outputs.PublicSubnetId
        InstanceProfileName: !GetAtt IAMStack.Outputs.InstanceProfileName
        AMIID: !Ref AMIID

Outputs:
  EC2PublicIP:
    Description: Public IP of the EC2 instance.
    Value: !GetAtt EC2Stack.Outputs.EC2PublicIP
  S3BucketName:
    Description: Name of the S3 Bucket.
    Value: !GetAtt S3Stack.Outputs.S3BucketName
```

### Запуск

Заходимо на веб морді в CloudFormation створюємо стек та пи створенні заванатжує файл main_stack.yaml

Після цього чекаємо поки весь стек створиться
